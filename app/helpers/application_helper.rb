module ApplicationHelper
  def mcp_endpoint_url
    host = Rails.configuration.x.api_host
    host.present? ? "https://#{host}/mcp" : "#{request.base_url}/mcp"
  end

  def show_auth_warning?
    return false if Sessy.saas?

    !Rails.env.local? &&
      ENV["HTTP_AUTH_USERNAME"].blank? &&
      ENV["HTTP_AUTH_PASSWORD"].blank? &&
      ENV["DISABLE_AUTH_WARNING"].blank?
  end
end
