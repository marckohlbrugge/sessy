class McpServer::SearchEvents < McpServer::BaseTool
  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100

  tool_name "search_events"
  title "Search events"
  description "Search email events (sends, deliveries, bounces, complaints, opens, clicks), newest first. Returns compact rows; use get_message with a row's ses_message_id for the full timeline. The date window defaults to the last 30 days — pass date_range \"all_time\" to search everything."
  input_schema(
    properties: {
      source_id: { type: "integer", description: "Limit to one source (id from list_sources); omit to search all sources" },
      query: { type: "string", description: "Substring match against recipient email addresses and message subjects" },
      event_types: { type: "array", items: { type: "string", enum: Event::Types::TYPES.keys.map(&:to_s) }, description: "Only these event types" },
      bounce_types: { type: "array", items: { type: "string", enum: Event.bounce_types }, description: "Only these bounce subtypes (combine with event_types [\"bounce\"])" },
      date_range: { type: "string", enum: Event.date_range_presets.keys + [ "custom" ], description: "Date window preset (default last_30_days); use custom with from_date/to_date" },
      from_date: { type: "string", description: "ISO 8601 date or timestamp; only with date_range custom" },
      to_date: { type: "string", description: "ISO 8601 date or timestamp; only with date_range custom" },
      limit: { type: "integer", minimum: 1, maximum: MAX_LIMIT, description: "Rows per page (default #{DEFAULT_LIMIT})" },
      cursor: { type: "string", description: "next_cursor value from the previous page" }
    },
    required: [],
    additionalProperties: false
  )

  def self.perform(account:, source_id: nil, query: nil, event_types: nil, bounce_types: nil,
    date_range: nil, from_date: nil, to_date: nil, limit: DEFAULT_LIMIT, cursor: nil, **)
    date_params = resolve_date_params(date_range: date_range, from_date: from_date, to_date: to_date)
    filter_params = date_params.merge(event_types: event_types, bounce_types: bounce_types)
    limit = limit.clamp(1, MAX_LIMIT)

    events = account_events(account)
    events = events.where(source_id: find_source!(account, source_id).id) if source_id.present?
    events = events.search(query) if query.present?
    events = events.filter_by_params(filter_params)
    events = apply_cursor(events, cursor)

    rows = events.order(event_at: :desc, id: :desc).limit(limit + 1).includes(:message).to_a
    has_more = rows.size > limit
    rows = rows.first(limit)

    payload = {
      events: rows.map { |event| row(event) },
      has_more: has_more,
      next_cursor: has_more ? encode_cursor(rows.last) : nil,
      applied_date_range: applied_date_range(date_params)
    }
    if rows.empty? && (hint = empty_result_hint(date_params))
      payload[:hint] = hint
    end
    payload
  end

  class << self
    private

    def row(event)
      {
        event_type: event.event_type,
        bounce_type: event.bounce_type,
        recipient_email: event.recipient_email,
        subject: event.message&.subject,
        ses_message_id: event.ses_message_id,
        event_at: event.event_at.iso8601
      }.compact
    end

    # Keyset cursor over (event_at DESC, id DESC): stable while events keep
    # ingesting, unlike offsets, and deterministic across equal timestamps.
    def encode_cursor(event)
      Base64.urlsafe_encode64("#{event.event_at.utc.iso8601(6)}|#{event.id}", padding: false)
    end

    def apply_cursor(scope, cursor)
      return scope if cursor.blank?

      timestamp, id = Base64.urlsafe_decode64(cursor).split("|", 2)
      time = Time.iso8601(timestamp)
      scope.where("events.event_at < :time OR (events.event_at = :time AND events.id < :id)", time: time, id: Integer(id))
    rescue ArgumentError, TypeError
      # Fully qualified: singleton-class methods don't see BaseTool's lexical constants.
      raise McpServer::BaseTool::ToolError, "Invalid cursor. Pass the next_cursor value returned by the previous page, or omit it to start over."
    end
  end
end
