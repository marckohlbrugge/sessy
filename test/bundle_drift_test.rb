require "test_helper"

# Exercises bin/bundle-drift's --check classification against fixture
# lockfiles in a temp directory. The repair branch shells out to bundler
# with network access, so it stays covered by CI usage rather than tests.
class BundleDriftTest < ActiveSupport::TestCase
  test "in sync when saas lock only adds the engine" do
    out, status = run_check(oss: { "foo" => "1.0.0" }, saas: { "foo" => "1.0.0", "sessy-saas" => "0.1.0" })
    assert status.success?, out
    assert_match(/in sync/, out)
  end

  test "flags a version drift by gem name" do
    out, status = run_check(oss: { "foo" => "1.1.0" }, saas: { "foo" => "1.0.0", "sessy-saas" => "0.1.0" })
    assert_not status.success?
    assert_match(/foo: 1\.1\.0 \(Gemfile\.lock\) vs 1\.0\.0/, out)
  end

  test "flags a gem missing from the saas lock" do
    out, status = run_check(oss: { "foo" => "1.0.0", "bar" => "2.0.0" }, saas: { "foo" => "1.0.0", "sessy-saas" => "0.1.0" })
    assert_not status.success?
    assert_match(/bar: in Gemfile\.lock but not in Gemfile\.saas\.lock/, out)
  end

  test "flags a stale gem removed from Gemfile.lock" do
    out, status = run_check(oss: { "foo" => "1.0.0" }, saas: { "foo" => "1.0.0", "bar" => "2.0.0", "sessy-saas" => "0.1.0" })
    assert_not status.success?
    assert_match(/bar: no longer in Gemfile\.lock but still in Gemfile\.saas\.lock/, out)
  end

  private
    def run_check(oss:, saas:)
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "Gemfile.lock"), lockfile(oss))
        File.write(File.join(dir, "Gemfile.saas.lock"), lockfile(saas))
        # Unbundled env: CI's job-level RUBYOPT/BUNDLE_GEMFILE would otherwise
        # make the child resolve a Gemfile relative to the temp dir and crash.
        out = Bundler.with_unbundled_env do
          IO.popen([ RbConfig.ruby, Rails.root.join("bin/bundle-drift").to_s, "--check" ], chdir: dir, err: [ :child, :out ], &:read)
        end
        [ out, $? ]
      end
    end

    def lockfile(gems)
      specs = gems.map { |name, version| "    #{name} (#{version})" }.join("\n")
      dependencies = gems.keys.map { |name| "  #{name}" }.join("\n")
      <<~LOCKFILE
        GEM
          remote: https://rubygems.org/
          specs:
        #{specs}

        PLATFORMS
          ruby

        DEPENDENCIES
        #{dependencies}

        BUNDLED WITH
           2.7.2
      LOCKFILE
    end
end
