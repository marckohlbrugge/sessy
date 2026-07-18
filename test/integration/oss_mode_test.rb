require "test_helper"

# Guards R1: with the plain Gemfile, no SaaS behavior is reachable.
class OssModeTest < ActionDispatch::IntegrationTest
  setup do
    skip "sessy-saas engine is loaded" if Sessy.saas?
  end

  test "responses carry no edition header" do
    get root_path
    assert_response :success
    assert_nil response.headers["X-Sessy-Edition"]
  end

  test "saas info route does not resolve" do
    get "/saas/info"
    assert_response :not_found
  end

  test "header contains no hosted badge" do
    get root_path
    assert_select "[data-saas-badge]", count: 0
  end
end
