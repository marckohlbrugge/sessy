# Matches requests hitting the dedicated API host (hosted: api.sessy.do).
# Only meaningful when both API_HOST and APP_HOST are configured — self-hosted
# installs set neither, so this constraint never matches there.
class Routes::ApiHost
  def self.matches?(request)
    api_host.present? && app_host.present? && request.host == api_host
  end

  def self.api_host
    Rails.configuration.x.api_host
  end

  def self.app_host
    Rails.configuration.x.app_host
  end
end
