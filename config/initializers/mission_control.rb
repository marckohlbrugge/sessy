Rails.application.config.after_initialize do
  username = ENV.fetch("MISSION_CONTROL_USERNAME") { ENV["HTTP_AUTH_USERNAME"] }
  password = ENV.fetch("MISSION_CONTROL_PASSWORD") { ENV["HTTP_AUTH_PASSWORD"] }

  MissionControl::Jobs.http_basic_auth_enabled = username.present? && password.present?
  MissionControl::Jobs.http_basic_auth_user = username
  MissionControl::Jobs.http_basic_auth_password = password
end
