module Sessy
  class << self
    def db_adapter
      @db_adapter ||= DbAdapter.new(
        ENV.fetch("DATABASE_ADAPTER") {
          ENV["DATABASE_URL"]&.start_with?("postgres") ? "postgresql" : "sqlite"
        }
      )
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
