class McpServer::EmailStats < McpServer::BaseTool
  MAX_SERIES_DAYS = 120

  tool_name "email_stats"
  title "Email stats"
  description "Aggregate email stats for one source or the whole account over a date range: counts by event type, unique opens/clicks, bounce/complaint/open/click rates, bounce breakdown by subtype, and an optional daily time series. Rates are percentages of sends."
  input_schema(
    properties: {
      source_id: { type: "integer", description: "Limit to one source (id from list_sources); omit for the whole account" },
      date_range: { type: "string", enum: Event.date_range_presets.keys + [ "custom" ], description: "Date window preset (default last_30_days); use custom with from_date/to_date" },
      from_date: { type: "string", description: "ISO 8601 date or timestamp; only with date_range custom" },
      to_date: { type: "string", description: "ISO 8601 date or timestamp; only with date_range custom" },
      include_daily_series: { type: "boolean", description: "Include a per-day sent/delivered/bounced series (ranges up to #{MAX_SERIES_DAYS} days); default false" }
    },
    required: [],
    additionalProperties: false
  )

  def self.perform(account:, source_id: nil, date_range: nil, from_date: nil, to_date: nil, include_daily_series: false, **)
    date_params = resolve_date_params(date_range: date_range, from_date: from_date, to_date: to_date)

    events = account_events(account)
    source = find_source!(account, source_id) if source_id.present?
    events = events.where(source_id: source.id) if source

    from, to = Event.date_range_from_params(date_params)
    from ||= events.minimum(:event_at) || Time.current
    to ||= Time.current.end_of_day
    stats = ::EmailStats.new(events, from..to)

    payload = {
      scope: source ? { source_id: source.id, source_name: source.name } : { source_id: nil, source_name: "all sources" },
      applied_date_range: applied_date_range(date_params),
      counts: {
        sent: stats.sent_count,
        delivered: stats.delivered_count,
        bounced: stats.bounce_count,
        complaints: stats.complaint_count,
        opens: stats.open_count,
        clicks: stats.click_count,
        unique_opens: stats.unique_open_count,
        unique_clicks: stats.unique_click_count
      },
      rates_percent: {
        bounce: stats.bounce_rate.round(2),
        complaint: stats.complaint_rate.round(2),
        open: stats.open_rate.round(2),
        click: stats.click_rate.round(2)
      },
      bounce_breakdown: stats.bounce_breakdown
    }

    if include_daily_series
      span_days = (to.to_date - from.to_date).to_i + 1
      if span_days > MAX_SERIES_DAYS
        raise ToolError, "Daily series is limited to ranges of #{MAX_SERIES_DAYS} days or less (this range spans #{span_days}). Narrow the date range or drop include_daily_series."
      end
      payload[:daily_series] = daily_series(stats)
    end

    if stats.sent_count.zero? && (hint = empty_result_hint(date_params))
      payload[:hint] = hint
    end

    payload
  end

  class << self
    private

    def daily_series(stats)
      series = stats.daily_series
      {
        dates: series[:dates].map(&:iso8601),
        series: series[:series].map { |entry| { key: entry[:key], values: entry[:values] } }
      }
    end
  end
end
