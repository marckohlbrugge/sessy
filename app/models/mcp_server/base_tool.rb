class McpServer::BaseTool < MCP::Tool
  # Raised by tools for expected, caller-facing failures (unknown filter
  # values, missing records). Anything else renders as a generic internal
  # error: raw exception text never reaches programmatic callers.
  class ToolError < StandardError; end

  class << self
    # Every tool on this server reads the account's own closed dataset, so
    # declare the full set of behavior hints once.
    def inherited(subclass)
      super
      subclass.annotations(read_only_hint: true, idempotent_hint: true, destructive_hint: false, open_world_hint: false)
    end

    def call(server_context:, **args)
      json_response perform(**args, account: server_context[:account], app_base_url: server_context[:app_base_url])
    rescue ToolError => error
      error_response error.message
    rescue StandardError => error
      Rails.error.report(error)
      error_response "Internal error. It has been logged — try again, or adjust the arguments."
    end

    private

    # structured_content is the spec's machine-readable channel; the text
    # block mirrors it for clients that only read content.
    def json_response(payload)
      MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(payload) } ], structured_content: payload)
    end

    def error_response(message)
      MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
    end

    # Tenancy chokepoint: every query starts from the account's sources and
    # scopes by the denormalized source_id FK — ingestion always sets it, and
    # the 20260418120000 migration backfilled the historical NULLs, so the FK
    # is authoritative and keeps the composite events indexes in play.
    def account_events(account)
      Event.where(source_id: account.sources.select(:id))
    end

    def account_messages(account)
      Message.where(source_id: account.sources.select(:id))
    end

    def find_source!(account, source_id)
      account.sources.find_by(id: source_id) ||
        raise(ToolError, "Unknown source_id: #{source_id.to_i}. Use list_sources for this account's sources.")
    end

    def resolve_date_params(date_range: nil, from_date: nil, to_date: nil)
      if date_range == "custom"
        from_date = resolve_custom_date(:from_date, from_date)
        to_date = resolve_custom_date(:to_date, to_date, end_of_day: true)
      end

      { date_range: date_range, from_date: from_date, to_date: to_date }
    end

    # Agents naturally pass bare dates, and a date-only bound parses to
    # midnight — which would silently exclude the end day's own events.
    # Normalize date-only bounds to span the whole day; timestamped bounds
    # pass through untouched.
    def resolve_custom_date(key, value, end_of_day: false)
      return if value.blank?

      Time.iso8601(value)
      value
    rescue ArgumentError
      begin
        date = Date.parse(value)
        (end_of_day ? date.end_of_day : date.beginning_of_day).iso8601
      rescue ArgumentError
        raise ToolError, "Invalid #{key}: #{value}. Use an ISO 8601 date or timestamp."
      end
    end

    # What the caller should report back: the window actually applied, so an
    # invisible default never turns "outside the window" into "never sent".
    def applied_date_range(params)
      from, to = Event.date_range_from_params(params)
      {
        preset: params[:date_range].presence || "last_30_days",
        from: from&.iso8601,
        to: to&.iso8601
      }
    end

    def empty_result_hint(params)
      preset = params[:date_range].presence || "last_30_days"
      return if preset == "all_time"

      "No events in the applied #{preset.humanize.downcase} window. Older data may exist — retry with date_range \"all_time\" or a custom range."
    end

    # Diagnostic payloads quote remote SMTP servers; cap string length so an
    # attacker-authored diagnostic can't balloon the response.
    def truncate_strings(value, limit: 500)
      case value
      when String then value.truncate(limit)
      when Hash then value.transform_values { |nested| truncate_strings(nested, limit: limit) }
      when Array then value.map { |nested| truncate_strings(nested, limit: limit) }
      else value
      end
    end
  end
end
