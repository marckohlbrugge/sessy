require "test_helper"

class Sessy::Saas::InfosTest < ActionDispatch::IntegrationTest
  test "info page shows the engine version" do
    get saas_info_path
    assert_response :success
    assert_match Sessy::Saas::VERSION, response.body
  end

  test "header shows the hosted badge to a signed-in user" do
    user = User.create!(email_address: "badge@example.com")
    accounts(:instance).memberships.create!(user: user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }

    get root_path
    assert_response :success
    assert_select "[data-saas-badge]"
  end

  test "header shows sign out to a signed-in user" do
    user = User.create!(email_address: "signout@example.com")
    accounts(:instance).memberships.create!(user: user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }

    get root_path
    assert_response :success
    assert_select "form[action=?]", session_path do
      assert_select "button", text: "Sign out"
    end
  end
end
