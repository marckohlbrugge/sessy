require "test_helper"

class SessyBuildMetadataTest < ActiveSupport::TestCase
  setup do
    @revision_path = Rails.root.join("REVISION")
    @committed_at_path = Rails.root.join("COMMITTED_AT")
    @had_revision = @revision_path.exist?
    @had_committed_at = @committed_at_path.exist?
    @previous_revision = @had_revision ? File.read(@revision_path) : nil
    @previous_committed_at = @had_committed_at ? File.read(@committed_at_path) : nil
  end

  teardown do
    restore_build_file(@revision_path, @had_revision, @previous_revision)
    restore_build_file(@committed_at_path, @had_committed_at, @previous_committed_at)
  end

  test "revision reads SESSY_GIT_SHA" do
    with_env("SESSY_GIT_SHA" => "deadbeef") do
      assert_equal "deadbeef", Sessy.revision
    end
  end

  test "revision falls back to REVISION file" do
    with_env("SESSY_GIT_SHA" => nil) do
      File.write(@revision_path, "fromfile\n")
      assert_equal "fromfile", Sessy.revision
    end
  end

  test "committed_at parses SESSY_GIT_COMMITTED_AT" do
    with_env("SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z") do
      assert_equal Time.iso8601("2026-08-01T12:00:00Z"), Sessy.committed_at
    end
  end

  test "committed_at falls back to COMMITTED_AT file" do
    with_env("SESSY_GIT_COMMITTED_AT" => nil) do
      File.write(@committed_at_path, "2026-08-01T12:00:00Z")
      assert_equal Time.iso8601("2026-08-01T12:00:00Z"), Sessy.committed_at
    end
  end

  test "committed_at returns nil for invalid timestamps" do
    with_env("SESSY_GIT_COMMITTED_AT" => "not-a-time") do
      assert_nil Sessy.committed_at
    end
  end

  test "blank build files are treated as missing" do
    with_env("SESSY_GIT_SHA" => nil, "SESSY_GIT_COMMITTED_AT" => nil) do
      File.write(@revision_path, "   ")
      File.write(@committed_at_path, "")
      assert_nil Sessy.revision
      assert_nil Sessy.committed_at
    end
  end

  private

  def restore_build_file(path, had_file, contents)
    if had_file
      File.write(path, contents)
    elsif path.exist?
      File.delete(path)
    end
  end

  def with_env(vars)
    old_values = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
    yield
  ensure
    old_values.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end
end
