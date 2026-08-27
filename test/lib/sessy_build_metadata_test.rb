require "test_helper"

class SessyBuildMetadataTest < ActiveSupport::TestCase
  test "revision reads SESSY_GIT_SHA" do
    with_env("SESSY_GIT_SHA" => "deadbeef") do
      assert_equal "deadbeef", Sessy.revision
    end
  end

  test "committed_at parses SESSY_GIT_COMMITTED_AT" do
    with_env("SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z") do
      assert_equal Time.iso8601("2026-08-01T12:00:00Z"), Sessy.committed_at
    end
  end

  test "committed_at returns nil for invalid timestamps" do
    with_env("SESSY_GIT_COMMITTED_AT" => "not-a-time") do
      assert_nil Sessy.committed_at
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
