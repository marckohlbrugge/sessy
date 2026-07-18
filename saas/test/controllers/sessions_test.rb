require "test_helper"

class Sessy::Saas::SessionsTest < ActionDispatch::IntegrationTest
  test "full sign-in round trip for an existing member" do
    user = create_member

    post session_path, params: { email_address: user.email_address }
    code = MagicLink.last.code

    post session_code_path, params: { code: code }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "code from a different browser is rejected" do
    create_member
    post session_path, params: { email_address: "member@example.com" }
    code = MagicLink.last.code

    # New session (no pending-authentication cookie) simulates another browser.
    reset!
    post session_code_path, params: { code: code }
    assert_redirected_to new_session_path
  end

  test "a wrong-browser submission does not burn the real user's code" do
    create_member
    post session_path, params: { email_address: "member@example.com" }
    code = MagicLink.last.code

    # Attacker's browser (own pending cookie for a different email) submits the code.
    reset!
    post session_path, params: { email_address: "attacker@example.com" }
    post session_code_path, params: { code: code }
    assert_redirected_to session_code_path

    # The member's code is still valid — it wasn't consumed by the failed attempt.
    assert MagicLink.exists?(code: code)
  end

  test "an idle-expired session is rejected and requires re-auth" do
    user = create_member
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }
    get root_path
    assert_response :success

    Session.last.update_column(:updated_at, 31.days.ago)

    assert_difference -> { Session.count }, -1 do
      get root_path
    end
    assert_redirected_to new_session_path
  end

  test "a code cannot be reused" do
    user = create_member
    post session_path, params: { email_address: user.email_address }
    code = MagicLink.last.code

    post session_code_path, params: { code: code }
    assert_no_difference -> { Session.count } do
      post session_code_path, params: { code: code }
    end
    assert_not MagicLink.exists?(code: code)
  end

  test "unknown and known emails produce identical responses" do
    create_member

    post session_path, params: { email_address: "member@example.com" }
    known_status, known_location = response.status, response.headers["Location"]
    reset!
    post session_path, params: { email_address: "stranger@example.com" }

    assert_equal known_status, response.status
    assert_equal known_location, response.headers["Location"]
  end

  test "unknown email creates a user and mints a sign_up code" do
    assert_difference -> { User.count }, 1 do
      post session_path, params: { email_address: "new@example.com" }
    end
    assert MagicLink.last.for_sign_up?
  end

  test "hosted mode does not accept the old shared Basic credential" do
    with_env("HTTP_AUTH_USERNAME" => "admin", "HTTP_AUTH_PASSWORD" => "secret") do
      get root_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }
      assert_redirected_to new_session_path
    end
  end

  test "sign out destroys the session" do
    user = create_member
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end
    assert_redirected_to new_session_path
  end

  private

  def create_member(email: "member@example.com")
    user = User.create!(email_address: email)
    accounts(:instance).memberships.create!(user: user)
    user
  end

  def with_env(vars)
    originals = vars.transform_values { |_| :missing }
    vars.each { |k, v| originals[k] = ENV[k]; ENV[k] = v }
    yield
  ensure
    originals.each { |k, v| v == :missing ? ENV.delete(k) : ENV[k] = v }
  end
end
