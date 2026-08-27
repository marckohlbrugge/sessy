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

  test "revision falls back to REVISION file" do
    with_build_files_locked do
      with_env("SESSY_GIT_SHA" => nil) do
        write_build_file("REVISION", "fromfile\n")
        assert_equal "fromfile", Sessy.revision
      end
    end
  end

  test "committed_at falls back to COMMITTED_AT file" do
    with_build_files_locked do
      with_env("SESSY_GIT_COMMITTED_AT" => nil) do
        write_build_file("COMMITTED_AT", "2026-08-01T12:00:00Z")
        assert_equal Time.iso8601("2026-08-01T12:00:00Z"), Sessy.committed_at
      end
    end
  end

  test "blank build files are treated as missing" do
    with_build_files_locked do
      with_env("SESSY_GIT_SHA" => nil, "SESSY_GIT_COMMITTED_AT" => nil) do
        write_build_file("REVISION", "   ")
        write_build_file("COMMITTED_AT", "")
        assert_nil Sessy.revision
        assert_nil Sessy.committed_at
      end
    end
  end

  private

  def with_build_files_locked
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    lock_path = Rails.root.join("tmp/sessy_build_metadata_test.lock")
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      lock.flock(File::LOCK_EX)
      previous = snapshot_build_files
      begin
        yield
      ensure
        restore_build_files(previous)
        lock.flock(File::LOCK_UN)
      end
    end
  end

  def snapshot_build_files
    {
      "REVISION" => read_build_file_if_present("REVISION"),
      "COMMITTED_AT" => read_build_file_if_present("COMMITTED_AT")
    }
  end

  def restore_build_files(previous)
    previous.each do |name, contents|
      path = Rails.root.join(name)
      if contents.nil?
        File.delete(path) if path.exist?
      else
        File.write(path, contents)
      end
    end
  end

  def read_build_file_if_present(name)
    path = Rails.root.join(name)
    File.read(path) if path.exist?
  rescue Errno::ENOENT
    nil
  end

  def write_build_file(name, contents)
    File.write(Rails.root.join(name), contents)
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
