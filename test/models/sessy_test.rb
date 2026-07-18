require "test_helper"

class SessyTest < ActiveSupport::TestCase
  test "saas? reflects engine presence" do
    if defined?(Sessy::Saas)
      assert Sessy.saas?
    else
      assert_not Sessy.saas?
    end
  end

  test "saas? is memoized" do
    original = Sessy.saas?
    Sessy.instance_variable_set(:@saas, :sentinel)
    assert_equal :sentinel, Sessy.saas?
  ensure
    Sessy.instance_variable_set(:@saas, original)
  end
end

# config/boot.rb resolves BUNDLE_GEMFILE from SESSY_MODE before Bundler runs.
# Exercised in a subprocess (the resolution is frozen in this process), with
# bundler/setup and bootsnap/setup stubbed out so only the env logic runs.
class SessyModeSelectionTest < ActiveSupport::TestCase
  test "SESSY_MODE=saas selects Gemfile.saas" do
    assert_equal "Gemfile.saas", resolved_gemfile("SESSY_MODE" => "saas")
  end

  test "no SESSY_MODE selects Gemfile" do
    assert_equal "Gemfile", resolved_gemfile({})
  end

  test "explicit BUNDLE_GEMFILE wins over SESSY_MODE" do
    assert_equal "Gemfile", resolved_gemfile("SESSY_MODE" => "saas", "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s)
  end

  private
    STUB_REQUIRES = <<~RUBY
      module Kernel
        alias_method :__original_require, :require
        def require(name)
          return true if %w[ bundler/setup bootsnap/setup ].include?(name)
          __original_require(name)
        end
      end
    RUBY

    def resolved_gemfile(env)
      # Spawned with the bundler environment stripped: the parent test process
      # runs under bundler, whose env vars re-resolve BUNDLE_GEMFILE in child
      # processes before boot.rb gets the chance.
      env = { "SESSY_MODE" => nil, "BUNDLE_GEMFILE" => nil }.merge(env)
      script = "#{STUB_REQUIRES}; load #{Rails.root.join("config/boot.rb").to_s.inspect}; puts File.basename(ENV[\"BUNDLE_GEMFILE\"])"
      Bundler.with_unbundled_env do
        IO.popen(env, [ RbConfig.ruby, "-e", script ], &:read).strip
      end
    end
end
