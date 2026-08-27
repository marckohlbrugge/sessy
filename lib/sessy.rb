module Sessy
  class << self
    def db_adapter
      @db_adapter ||= DbAdapter.new(
        ENV.fetch("DATABASE_ADAPTER") {
          ENV["DATABASE_URL"]&.start_with?("postgres") ? "postgresql" : "sqlite"
        }
      )
    end

    # True when the sessy-saas engine is in the bundle (Gemfile.saas). The
    # SESSY_MODE env var only selects the gemfile in pre-boot entry points;
    # at runtime, engine presence is the single source of truth.
    def saas?
      return @saas if defined?(@saas)
      @saas = defined?(Sessy::Saas) ? true : false
    end

    # Git SHA baked into the Docker image (or SESSY_GIT_SHA / REVISION file).
    # Blank for local/dev builds that were not built with revision metadata.
    def revision
      ENV["SESSY_GIT_SHA"].presence || read_build_file("REVISION").presence
    end

    # Commit timestamp for {#revision}, used to express how many days an
    # install is behind the latest upstream commit.
    def committed_at
      raw = ENV["SESSY_GIT_COMMITTED_AT"].presence || read_build_file("COMMITTED_AT").presence
      raw && Time.iso8601(raw)
    rescue ArgumentError
      nil
    end

    private

    def read_build_file(name)
      path = Rails.root.join(name)
      File.read(path).strip if path.exist?
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end
  end

  class DbAdapter
    def initialize(name)
      @name = name.to_s
    end

    def to_s
      @name
    end

    def sqlite?
      @name == "sqlite"
    end

    def postgresql?
      @name == "postgresql"
    end
  end
end
