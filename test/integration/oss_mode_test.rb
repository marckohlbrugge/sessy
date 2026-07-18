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

  test "hosted auth routes do not resolve" do
    get "/session/new"
    assert_response :not_found
  end

  test "no hosted mailer delivery is configured" do
    assert_not_equal "app.sessy.do", ActionMailer::Base.default_url_options[:host]
    assert_not_equal :ses_v2, ActionMailer::Base.delivery_method
  end

  test "HTTP Basic still gates the app when configured" do
    with_env("HTTP_AUTH_USERNAME" => "admin", "HTTP_AUTH_PASSWORD" => "secret") do
      get root_path
      assert_response :unauthorized

      get root_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }
      assert_response :success
    end
  end

  private

  def with_env(vars)
    originals = {}
    vars.each { |k, v| originals[k] = ENV.key?(k) ? ENV[k] : :missing; ENV[k] = v }
    yield
  ensure
    originals.each { |k, v| v == :missing ? ENV.delete(k) : ENV[k] = v }
  end
end
