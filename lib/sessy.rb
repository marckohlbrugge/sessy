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
