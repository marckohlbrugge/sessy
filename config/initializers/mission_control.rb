Rails.application.config.after_initialize do
  if Sessy.saas?
    # Hosted mode never falls back to the retiring HTTP_AUTH_* chain and never
    # falls open: with no MISSION_CONTROL_* credentials configured, /jobs is
    # locked behind unguessable credentials rather than left unauthenticated.
    username = ENV["MISSION_CONTROL_USERNAME"]
    password = ENV["MISSION_CONTROL_PASSWORD"]

    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = username.presence || SecureRandom.hex(32)
    MissionControl::Jobs.http_basic_auth_password = password.presence || SecureRandom.hex(32)
  else
    username = ENV.fetch("MISSION_CONTROL_USERNAME") { ENV["HTTP_AUTH_USERNAME"] }
    password = ENV.fetch("MISSION_CONTROL_PASSWORD") { ENV["HTTP_AUTH_PASSWORD"] }

    MissionControl::Jobs.http_basic_auth_enabled = username.present? && password.present?
    MissionControl::Jobs.http_basic_auth_user = username
    MissionControl::Jobs.http_basic_auth_password = password
  end
end
