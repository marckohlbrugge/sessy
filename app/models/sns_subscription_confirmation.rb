# Confirms an SNS HTTPS subscription by fetching its SubscribeURL, as the SNS
# docs prescribe. Only URLs on SNS hosts are fetched: the SNS signature already
# covers SubscribeURL in production, but verification is bypassed locally and
# the allowlist costs nothing.
class SnsSubscriptionConfirmation
  SNS_HOST = /\Asns\.[a-z0-9-]+\.amazonaws\.com\z/
  NETWORK_ERRORS = [ SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, IOError ].freeze

  # Performs the GET. Swappable so tests can stand in for SNS without a real
  # request; the class method form of Net::HTTP.get_response takes no timeouts.
  mattr_accessor :fetcher, default: ->(uri) {
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 5) do |http|
      http.get(uri.request_uri)
    end
  }

  def initialize(subscribe_url)
    @uri = URI.parse(subscribe_url.to_s)
  rescue URI::InvalidURIError
    @uri = nil
  end

  def host
    uri&.host
  end

  def sns_url?
    uri.is_a?(URI::HTTPS) && host.to_s.match?(SNS_HOST)
  end

  # True only when SNS answered 2xx with a SubscriptionArn; anything else is a
  # failure the caller should report back to SNS so it retries.
  def confirm
    response = fetcher.call(uri)
    response.is_a?(Net::HTTPSuccess) && response.body.to_s.include?("SubscriptionArn")
  rescue *NETWORK_ERRORS => e
    Rails.logger.error("SNS subscription confirmation request to #{host} failed: #{e.class}: #{e.message}")
    false
  end

  private

  # Never exposed: the URL carries a one-time token that must stay out of logs.
  attr_reader :uri
end
