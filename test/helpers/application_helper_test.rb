require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    @previous_force = UpdateCheck.force_enabled
    @previous_fetcher = UpdateCheck.fetcher
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    UpdateCheck.force_enabled = @previous_force
    UpdateCheck.fetcher = @previous_fetcher
    Rails.cache = @previous_cache
  end

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

  test "show_update_banner? returns false when update check is blank" do
    UpdateCheck.force_enabled = false
    assert_not show_update_banner?
  end

  test "show_update_banner? returns true when status is outdated" do
    with_env("SESSY_GIT_SHA" => "abc1234", "SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z") do
      UpdateCheck.force_enabled = true
      UpdateCheck.fetcher = ->(_uri) {
        {
          "sha" => "def5678",
          "commit" => { "committer" => { "date" => "2026-08-10T12:00:00Z" } }
        }
      }

      assert show_update_banner?
      assert_equal 9, update_check_status.days_behind
    end
  end

  test "show_update_banner? returns false when status is current" do
    with_env("SESSY_GIT_SHA" => "abc1234", "SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z") do
      UpdateCheck.force_enabled = true
      UpdateCheck.fetcher = ->(_uri) {
        {
          "sha" => "abc1234full",
          "commit" => { "committer" => { "date" => "2026-08-01T12:00:00Z" } }
        }
      }

      assert_not show_update_banner?
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
