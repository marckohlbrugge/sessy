# Aggregate email stats over an events scope and date range, shared by the
# source dashboard and the MCP email_stats tool.
class EmailStats
  attr_reader :range

  def initialize(events, range)
    @events = events.where(event_at: range)
    @range = range
  end

  def counts
    @counts ||= @events.group(:event_type).count
  end

  def sent_count = counts["send"] || 0
  def delivered_count = counts["delivery"] || 0
  def bounce_count = counts["bounce"] || 0
  def complaint_count = counts["complaint"] || 0
  def open_count = counts["open"] || 0
  def click_count = counts["click"] || 0

  def unique_open_count = unique_counts["open"] || 0
  def unique_click_count = unique_counts["click"] || 0

  def bounce_rate = percent(bounce_count, sent_count)
  def complaint_rate = percent(complaint_count, sent_count)
  def open_rate = percent(unique_open_count, sent_count)
  def click_rate = percent(unique_click_count, sent_count)

  def bounce_breakdown
    @events.event_type_bounce.group(:bounce_type).count.transform_keys do |bounce_type|
      bounce_type.presence || "Unknown"
    end
  end

  # Daily sent/delivered/bounced series with zero-filled dates.
  def daily_series
    rows = @events
      .where(event_type: [ :send, :delivery, :bounce ])
      .group(Arel.sql("DATE(events.event_at)"))
      .pluck(
        Arel.sql("DATE(events.event_at)"),
        Arel.sql("SUM(CASE WHEN events.event_type = 'Send' THEN 1 ELSE 0 END)"),
        Arel.sql("SUM(CASE WHEN events.event_type = 'Delivery' THEN 1 ELSE 0 END)"),
        Arel.sql("SUM(CASE WHEN events.event_type = 'Bounce' THEN 1 ELSE 0 END)")
      )

    by_date = rows.each_with_object({}) do |(day, sent, delivered, bounced), hash|
      key = day.is_a?(Date) ? day : Date.parse(day.to_s)
      hash[key] = { sent: sent.to_i, delivered: delivered.to_i, bounced: bounced.to_i }
    end

    dates = (range.begin.to_date..range.end.to_date).to_a
    series = %i[sent delivered bounced].map do |key|
      values = dates.map { |date| by_date.dig(date, key) || 0 }
      { key:, values: }
    end

    { dates:, series: }
  end

  private

  # Columns qualified: the MCP tools feed in scopes joined to messages, which
  # also has a ses_message_id column.
  def unique_counts
    @unique_counts ||= @events.where(event_type: %i[open click])
      .group(:event_type)
      .count(Arel.sql("DISTINCT events.recipient_email || '|' || events.ses_message_id"))
  end

  def percent(value, total)
    return 0 if total.zero?

    (value.to_f / total) * 100
  end
end
