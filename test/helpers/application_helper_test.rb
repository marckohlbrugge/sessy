require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "show_auth_warning? returns false in local environment" do
    assert_not show_auth_warning?
  end

  test "show_auth_warning? returns false when HTTP auth is configured" do
    with_env("HTTP_AUTH_USERNAME" => "user", "HTTP_AUTH_PASSWORD" => "pass") do
      assert_not show_auth_warning?
    end
  end

  test "show_auth_warning? returns false when warning is disabled" do
    with_env("DISABLE_AUTH_WARNING" => "1") do
      assert_not show_auth_warning?
    end
  end

  private

  def with_env(vars)
    old_values = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old_values.each { |k, v| ENV[k] = v }
  end
end
