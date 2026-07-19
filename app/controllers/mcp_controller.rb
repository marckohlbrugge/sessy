# Streamable HTTP endpoint for the MCP server. Stateless: every POST is
# self-contained, so it runs fine across multiple Puma workers with no session
# affinity. Inherits from ActionController::API because MCP clients are not
# browsers (no cookies, CSRF, or flash) — and so the SaaS engine's session
# auth and approval gate, which target ApplicationController, never apply:
# bearer-key auth below is the whole story in both editions.
class McpController < ActionController::API
  KEY_RATE_LIMIT = 60
  INVALID_KEY_RATE_LIMIT = 10
  MAX_REQUEST_BYTES = 1.megabyte

  # Rate-limit counters need a real cache (Solid Cache in production, shared
  # across processes); the test environment's :null_store never increments.
  # rate_limit captures its store when the class loads, so the delegator below
  # lets tests swap in a MemoryStore at runtime.
  mattr_accessor :rate_limit_store, default: Rails.cache

  class SwappableStore
    def increment(...) = McpController.rate_limit_store.increment(...)
  end

  # The invalid-key rule is declared ahead of require_api_key so it still runs
  # on the 401 path — token guessing must not be uncapped. (Deliberate
  # divergence from startupjobs, where auth halts before its limiters.)
  rate_limit to: INVALID_KEY_RATE_LIMIT, within: 1.minute, name: "invalid_key", store: SwappableStore.new,
    by: -> { request.remote_ip }, with: -> { render_rate_limited }, if: -> { current_api_key.nil? }
  rate_limit to: KEY_RATE_LIMIT, within: 1.minute, name: "key", store: SwappableStore.new,
    by: -> { current_api_key.id }, with: -> { render_rate_limited }, if: -> { current_api_key.present? }

  before_action :redirect_browsers
  before_action :require_api_key

  def handle
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      McpServer.server(account: Current.account, api_key: current_api_key, app_base_url: app_base_url),
      stateless: true,
      enable_json_response: true,
      # Host/Origin validation guards local loopback servers against DNS
      # rebinding; this is a public endpoint behind a proxy, and with no
      # anonymous tier a rebound browser request carries no credentials.
      dns_rebinding_protection: false,
      max_request_bytes: MAX_REQUEST_BYTES
    )

    status, headers, body = transport.handle_request(request)

    self.status = status
    headers.each { |key, value| response.set_header(key, value) }
    # 202s for notifications come back without a Content-Type and would
    # otherwise default to text/html.
    response.set_header("Content-Type", "application/json") if headers["Content-Type"].blank?
    self.response_body = body
  end

  private

  def current_api_key
    return @current_api_key if defined?(@current_api_key)

    token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    @current_api_key = ApiKey.find_by_token(token)
  end

  # Missing, unknown, and revoked tokens all take this one path, so the 401 is
  # byte-identical in every case and never echoes the presented token.
  def require_api_key
    if current_api_key.nil?
      response.set_header("WWW-Authenticate", 'Bearer realm="Sessy MCP"')
      render json: { error: "Missing or invalid API key. Create one at #{app_base_url}/api_keys and connect with an Authorization: Bearer header." },
        status: :unauthorized
      return
    end

    unless current_api_key.account.approved?
      render json: { error: "This account is pending approval, so the MCP server is not active yet. Visit #{app_base_url} for status." },
        status: :forbidden
      return
    end

    current_api_key.track_usage
    Current.account = current_api_key.account
  end

  def render_rate_limited
    response.set_header("Retry-After", "60")
    render json: { error: "Rate limit exceeded. Slow down and retry shortly." }, status: :too_many_requests
  end

  def browser_request?
    request.headers["Accept"].to_s.exclude?("text/event-stream")
  end

  # A browser hitting the endpoint gets the human docs instead of a 405 — as
  # an absolute URL on the primary app host, so hosted visitors never sign in
  # on the api subdomain (head instead of redirect_to: this controller must
  # never produce a text/html response).
  def redirect_browsers
    head :found, location: "#{app_base_url}#{mcp_docs_path}" if request.get? && browser_request?
  end

  def app_base_url
    @app_base_url ||= Rails.configuration.x.app_host.present? ? "https://#{Rails.configuration.x.app_host}" : request.base_url
  end
end
