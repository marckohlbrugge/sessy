require "test_helper"

class Sessy::Saas::InfosTest < ActionDispatch::IntegrationTest
  test "info page shows the engine version" do
    get saas_info_path
    assert_response :success
    assert_match Sessy::Saas::VERSION, response.body
  end

  test "header shows the hosted badge" do
    get root_path
    assert_select "[data-saas-badge]"
  end
end
