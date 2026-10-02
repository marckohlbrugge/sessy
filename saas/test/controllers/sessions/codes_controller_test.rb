require "test_helper"

# The return-to path set by request_authentication when a signed-out visitor
# hits a tenant page (the welcome email's Setup deep link, AE5).
class Sessy::Saas::Sessions::CodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: Time.current)
    @user = User.create!(email_address: "casey@example.com")
    @account.memberships.create!(user: @user, role: "owner")
    @source = @account.sources.create!(name: "Production")
  end

  test "a signed-out visit to a Setup page is resumed after entering the code" do
    get source_setup_path(@source)
    assert_redirected_to new_session_path

    sign_in_with_code @user
    assert_redirected_to source_setup_path(@source)
    follow_redirect!
    assert_response :success
  end

  test "the stored path is consumed by one sign-in" do
    get source_setup_path(@source)
    sign_in_with_code @user
    assert_redirected_to source_setup_path(@source)

    delete session_path
    sign_in_with_code @user
    assert_redirected_to root_path
  end

  test "a valid code with nothing stored goes to the root" do
    sign_in_with_code @user
    assert_redirected_to root_path
  end

  test "a membership-less user is sent to complete signup regardless of a stored path" do
    get source_setup_path(@source)

    stranger = User.create!(email_address: "stranger@example.com")
    sign_in_with_code stranger
    assert_redirected_to new_signup_completion_path
  end

  test "non-GET requests do not store a return path" do
    patch source_setup_path(@source), params: { source: { aws_region: "us-east-1" } }
    assert_redirected_to new_session_path

    sign_in_with_code @user
    assert_redirected_to root_path
  end

  private

  def sign_in_with_code(user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }
  end
end

# A stored value that is not a same-origin path must never become a redirect
# target; functional tests can seed the session with hostile values the
# request path itself can no longer produce.
class Sessy::Saas::Sessions::CodesControllerReturnPathTest < ActionController::TestCase
  tests Sessy::Saas::Sessions::CodesController

  setup do
    account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: Time.current)
    @user = User.create!(email_address: "casey@example.com")
    account.memberships.create!(user: @user, role: "owner")
  end

  test "a stored absolute URL on another host falls back to the root" do
    session[:return_to_after_authenticating] = "https://evil.example/sources/1/setup"

    submit_valid_code
    assert_redirected_to root_path
  end

  test "a stored protocol-relative URL falls back to the root" do
    session[:return_to_after_authenticating] = "//evil.example/x"

    submit_valid_code
    assert_redirected_to root_path
  end

  test "a stored same-origin path is honoured" do
    session[:return_to_after_authenticating] = "/sources/42/setup"

    submit_valid_code
    assert_redirected_to "/sources/42/setup"
  end

  private

  def submit_valid_code
    magic_link = @user.mint_magic_link(purpose: :sign_in)
    cookies[:pending_authentication_token] =
      Rails.application.message_verifier(:pending_authentication).generate(@user.email_address, expires_at: magic_link.expires_at)

    post :create, params: { code: magic_link.code }
  end
end
