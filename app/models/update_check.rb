# frozen_string_literal: true

require "net/http"
require "json"
require "cgi"

# Compares the baked-in git revision of a self-hosted install against the
# latest commit on GitHub (public API, no token). Results are cached so page
# loads do not hit GitHub every request. Opt out with DISABLE_UPDATE_CHECKS=true.
class UpdateCheck
  CACHE_TTL = 24.hours
  FAILURE_TTL = 1.hour
  REQUEST_TIMEOUT = 2
  DEFAULT_REPO = "marckohlbrugge/sessy"
  DEFAULT_REF = "main"
  REPO_PATTERN = /\A[\w.-]+\/[\w.-]+\z/
  REF_PATTERN = /\A[\w.\/-]+\z/

  Status = Data.define(:latest_sha, :latest_committed_at, :days_behind) do
    def outdated?
      days_behind.positive?
    end

    def compare_url
      "https://github.com/#{UpdateCheck.repo}/compare/#{Sessy.revision}...#{UpdateCheck.ref}"
    end

    def docker_image
      UpdateCheck.docker_image
    end
  end

  class << self
    # Overridable in tests. Receives a URI, returns a parsed JSON Hash.
    attr_accessor :fetcher

    # When set (true/false), bypasses the normal enabled? heuristics. Used by tests.
    attr_accessor :force_enabled

    def enabled?
      return force_enabled unless force_enabled.nil?
      return false if Sessy.saas?
      return false if Rails.env.local?
      return false if ENV["DISABLE_UPDATE_CHECKS"].present?
      return false if Sessy.revision.blank? || Sessy.committed_at.blank?

      true
    end

    def current
      return unless enabled?

      cached = Rails.cache.read(cache_key)
      return if cached == :unavailable
      return status_from_cache(cached) if cached.is_a?(Hash)

      fetch_mutex.synchronize { fetch_and_cache }
    end

    def refresh!
      Rails.cache.delete(cache_key)
      current
    end

    def repo
      value = ENV["SESSY_GITHUB_REPO"].presence || DEFAULT_REPO
      return value if value.match?(REPO_PATTERN)

      Rails.logger.warn("[UpdateCheck] Ignoring invalid SESSY_GITHUB_REPO=#{value.inspect}")
      DEFAULT_REPO
    end

    def ref
      value = ENV["SESSY_GITHUB_REF"].presence || DEFAULT_REF
      return value if value.match?(REF_PATTERN)

      Rails.logger.warn("[UpdateCheck] Ignoring invalid SESSY_GITHUB_REF=#{value.inspect}")
      DEFAULT_REF
    end

    def docker_image
      "ghcr.io/#{repo.downcase}:#{ref}"
    end

    def cache_key
      "sessy/update_check/#{Sessy.revision}/#{repo}/#{ref}"
    end

    private

    def fetch_mutex
      @fetch_mutex ||= Mutex.new
    end

    def fetch_and_cache
      cached = Rails.cache.read(cache_key)
      return if cached == :unavailable
      return status_from_cache(cached) if cached.is_a?(Hash)

      status = fetch_remote
      Rails.cache.write(cache_key, status_to_cache(status), expires_in: CACHE_TTL)
      status
    rescue StandardError => e
      Rails.logger.warn("[UpdateCheck] #{e.class}: #{e.message}")
      Rails.cache.write(cache_key, :unavailable, expires_in: FAILURE_TTL)
      nil
    end

    def fetch_remote
      uri = URI("https://api.github.com/repos/#{repo}/commits/#{CGI.escape(ref)}")
      response = (fetcher || method(:get_json)).call(uri)

      latest_sha = response.fetch("sha")
      latest_committed_at = Time.iso8601(
        response.dig("commit", "committer", "date") ||
          response.dig("commit", "author", "date")
      )

      build_status(latest_sha: latest_sha, latest_committed_at: latest_committed_at)
    end

    def build_status(latest_sha:, latest_committed_at:)
      days_behind = if sha_matches?(latest_sha)
        0
      else
        (latest_committed_at.to_date - Sessy.committed_at.to_date).to_i
      end

      Status.new(
        latest_sha: latest_sha,
        latest_committed_at: latest_committed_at,
        days_behind: [ days_behind, 0 ].max
      )
    end

    def sha_matches?(latest_sha)
      revision = Sessy.revision.to_s
      revision.present? && (latest_sha.start_with?(revision) || revision.start_with?(latest_sha))
    end

    def get_json(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = REQUEST_TIMEOUT
      http.read_timeout = REQUEST_TIMEOUT
      http.write_timeout = REQUEST_TIMEOUT if http.respond_to?(:write_timeout=)
      http.ssl_timeout = REQUEST_TIMEOUT if http.respond_to?(:ssl_timeout=)
      http.max_retries = 0 if http.respond_to?(:max_retries=)

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "Sessy (+https://github.com/marckohlbrugge/sessy)"

      response = http.request(request)
      raise "GitHub API #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def status_to_cache(status)
      {
        "latest_sha" => status.latest_sha,
        "latest_committed_at" => status.latest_committed_at.iso8601
      }
    end

    def status_from_cache(cached)
      cached = cached.stringify_keys
      build_status(
        latest_sha: cached.fetch("latest_sha"),
        latest_committed_at: Time.iso8601(cached.fetch("latest_committed_at"))
      )
    end
  end
end
