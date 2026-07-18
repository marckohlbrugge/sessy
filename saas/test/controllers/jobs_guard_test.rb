require "test_helper"

class Sessy::Saas::JobsGuardTest < ActionDispatch::IntegrationTest
  test "jobs dashboard is locked in hosted mode without operator credentials" do
    # No MISSION_CONTROL_* set in the test env, so /jobs must be locked rather
    # than falling open (AE8). Basic auth is enabled with unguessable creds.
    assert MissionControl::Jobs.http_basic_auth_enabled
    assert MissionControl::Jobs.http_basic_auth_user.present?
    assert MissionControl::Jobs.http_basic_auth_password.present?
  end

  test "an unauthenticated jobs request redirects to sign-in, not 500" do
    # /jobs is a mounted engine; the auth redirect must resolve against main_app
    # or URL generation blows up inside the engine routing context.
    get "/jobs"
    assert_redirected_to "/session/new"
  end

  test "a signed-in user without operator credentials cannot open jobs" do
    user = User.create!(email_address: "jobs@example.com")
    accounts(:instance).memberships.create!(user: user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }

    get "/jobs"
    assert_response :unauthorized
  end
end
