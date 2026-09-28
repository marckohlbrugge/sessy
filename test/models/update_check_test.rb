require "test_helper"

class UpdateCheckTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    @previous_fetcher = UpdateCheck.fetcher
    @previous_force = UpdateCheck.force_enabled
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    UpdateCheck.force_enabled = true
  end

  teardown do
    Rails.cache = @previous_cache
    UpdateCheck.fetcher = @previous_fetcher
    UpdateCheck.force_enabled = @previous_force
  end

  test "enabled? is false in local environments by default" do
    UpdateCheck.force_enabled = nil
    with_build_metadata do
      assert_not UpdateCheck.enabled?
    end
  end

  test "enabled? is false when update checks are disabled" do
    UpdateCheck.force_enabled = nil
    with_build_metadata("DISABLE_UPDATE_CHECKS" => "true") do
      assert_not UpdateCheck.enabled?
    end
  end

  test "enabled? is false without baked revision metadata" do
    UpdateCheck.force_enabled = nil
    with_env("SESSY_GIT_SHA" => nil, "SESSY_GIT_COMMITTED_AT" => nil, "DISABLE_UPDATE_CHECKS" => nil) do
      assert_not UpdateCheck.enabled?
    end
  end

  test "enabled? respects force_enabled override" do
    UpdateCheck.force_enabled = true
    assert UpdateCheck.enabled?

    UpdateCheck.force_enabled = false
    assert_not UpdateCheck.enabled?
  end

  test "current reports days behind when upstream is newer" do
    with_build_metadata do
      stub_github_commit(sha: "def5678", date: "2026-08-10T12:00:00Z")

      status = UpdateCheck.current

      assert status.outdated?
      assert_equal 9, status.days_behind
      assert_equal "def5678", status.latest_sha
      assert_includes status.compare_url, "#{Sessy.revision}...main"
      assert_equal "ghcr.io/marckohlbrugge/sessy:main", status.docker_image
    end
  end

  test "current is not outdated when SHAs match" do
    with_build_metadata("SESSY_GIT_SHA" => "abc1234") do
      stub_github_commit(sha: "abc1234fullsha", date: "2026-08-20T12:00:00Z")

      status = UpdateCheck.current

      assert_not status.outdated?
      assert_equal 0, status.days_behind
    end
  end

  test "current is not outdated when upstream commit is older" do
    with_build_metadata do
      stub_github_commit(sha: "old9999", date: "2026-07-01T12:00:00Z")

      status = UpdateCheck.current

      assert_not status.outdated?
      assert_equal 0, status.days_behind
    end
  end

  test "current uses author date when committer date is missing" do
    with_build_metadata do
      UpdateCheck.fetcher = ->(_uri) {
        {
          "sha" => "def5678",
          "commit" => {
            "author" => { "date" => "2026-08-10T12:00:00Z" }
          }
        }
      }

      status = UpdateCheck.current

      assert_equal 9, status.days_behind
    end
  end

  test "current caches successful responses" do
    with_build_metadata do
      calls = 0
      UpdateCheck.fetcher = ->(_uri) {
        calls += 1
        github_payload(sha: "def5678", date: "2026-08-10T12:00:00Z")
      }

      UpdateCheck.current
      UpdateCheck.current

      assert_equal 1, calls
    end
  end

  test "current returns nil and skips fetcher while failure is cached" do
    with_build_metadata do
      calls = 0
      UpdateCheck.fetcher = ->(_uri) {
        calls += 1
        raise Timeout::Error, "timed out"
      }

      assert_nil UpdateCheck.current
      assert_equal :unavailable, Rails.cache.read(UpdateCheck.cache_key)

      assert_nil UpdateCheck.current
      assert_equal 1, calls
    end
  end

  test "cache is scoped to the running revision after an image upgrade" do
    with_build_metadata("SESSY_GIT_SHA" => "oldrev") do
      stub_github_commit(sha: "newrev", date: "2026-08-10T12:00:00Z")
      stale = UpdateCheck.current
      assert stale.outdated?
    end

    with_build_metadata("SESSY_GIT_SHA" => "newrev", "SESSY_GIT_COMMITTED_AT" => "2026-08-10T12:00:00Z") do
      calls = 0
      UpdateCheck.fetcher = ->(_uri) {
        calls += 1
        github_payload(sha: "newrev", date: "2026-08-10T12:00:00Z")
      }

      status = UpdateCheck.current

      assert_not status.outdated?
      assert_equal 1, calls
      assert_equal 0, status.days_behind
    end
  end

  test "status_from_cache recomputes days_behind for the current revision" do
    with_build_metadata("SESSY_GIT_SHA" => "abc1234", "SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z") do
      Rails.cache.write(
        UpdateCheck.cache_key,
        { "latest_sha" => "abc1234full", "latest_committed_at" => "2026-08-20T12:00:00Z" },
        expires_in: UpdateCheck::CACHE_TTL
      )

      status = UpdateCheck.current

      assert_not status.outdated?
      assert_equal 0, status.days_behind
    end
  end

  test "refresh! clears the cache and fetches again" do
    with_build_metadata do
      stub_github_commit(sha: "def5678", date: "2026-08-10T12:00:00Z")
      UpdateCheck.current

      stub_github_commit(sha: "fff0000", date: "2026-08-15T12:00:00Z")
      status = UpdateCheck.refresh!

      assert_equal "fff0000", status.latest_sha
      assert_equal 14, status.days_behind
    end
  end

  test "current is skipped when disabled" do
    UpdateCheck.force_enabled = false
    calls = 0
    UpdateCheck.fetcher = ->(_uri) {
      calls += 1
      github_payload(sha: "def5678", date: "2026-08-10T12:00:00Z")
    }

    assert_nil UpdateCheck.current
    assert_equal 0, calls
  end

  test "repo and ref fall back to defaults when env values are invalid" do
    with_env("SESSY_GITHUB_REPO" => "not a repo", "SESSY_GITHUB_REF" => "bad ref?") do
      assert_equal UpdateCheck::DEFAULT_REPO, UpdateCheck.repo
      assert_equal UpdateCheck::DEFAULT_REF, UpdateCheck.ref
    end
  end

  test "docker_image follows configured repo and ref" do
    with_env("SESSY_GITHUB_REPO" => "acme/sessy-fork", "SESSY_GITHUB_REF" => "stable") do
      assert_equal "ghcr.io/acme/sessy-fork:stable", UpdateCheck.docker_image
    end
  end

  private

  def with_build_metadata(extra = {})
    defaults = {
      "SESSY_GIT_SHA" => "abc1234",
      "SESSY_GIT_COMMITTED_AT" => "2026-08-01T12:00:00Z",
      "DISABLE_UPDATE_CHECKS" => nil,
      "SESSY_GITHUB_REPO" => nil,
      "SESSY_GITHUB_REF" => nil
    }
    with_env(defaults.merge(extra)) { yield }
  end

  def stub_github_commit(sha:, date:)
    UpdateCheck.fetcher = ->(_uri) { github_payload(sha: sha, date: date) }
  end

  def github_payload(sha:, date:)
    {
      "sha" => sha,
      "commit" => {
        "committer" => { "date" => date }
      }
    }
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
