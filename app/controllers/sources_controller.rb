class SourcesController < ApplicationController
  before_action :set_source, only: %i[show edit update destroy]

  def index
    @sources = Source.alphabetically
    @source_stats = source_index_stats(@sources)
  end

  def show
    range_start = 29.days.ago.to_date
    range_end = Time.zone.today
    @overview_range = range_start.beginning_of_day..range_end.end_of_day
    @overview_events = @source.events.where(event_at: @overview_range)

    assign_overview_counts(@overview_events)

    @bounce_rate = percent(@bounce_count, @sent_count)
    @complaint_rate = percent(@complaint_count, @sent_count)
    @open_rate = percent(@unique_open_count, @sent_count)
    @click_rate = percent(@unique_click_count, @sent_count)

    @chart_data = build_chart_data(@overview_events, range_start, range_end)
    @sent_today_count = @chart_data[:series].find { |s| s[:key] == :sent }[:values].last || 0
    @bounce_breakdown = bounce_breakdown(@overview_events)
  end

  def new
    @source = Source.new(color: Source.next_available_color)
  end

  def create
    @source = Source.new(source_params)

    if @source.save
      redirect_to @source, notice: "Source created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @source.update(source_params)
      redirect_to @source, notice: "Source updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @source.destroy
    redirect_to sources_path, notice: "Source deleted."
  end

  private

  def set_source
    @source = Source.find(params[:id])
  end

  def source_params
    params.require(:source).permit(:name, :color, :retention_days)
  end

  def percent(value, total)
    return 0 if total.zero?

    (value.to_f / total) * 100
  end

  def assign_overview_counts(events)
    row = events.pick(
      Arel.sql("SUM(CASE WHEN event_type = 'Send' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN event_type = 'Delivery' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN event_type = 'Bounce' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN event_type = 'Complaint' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN event_type = 'Open' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN event_type = 'Click' THEN 1 ELSE 0 END)"),
      Arel.sql("COUNT(DISTINCT CASE WHEN event_type = 'Open' THEN recipient_email || '|' || ses_message_id END)"),
      Arel.sql("COUNT(DISTINCT CASE WHEN event_type = 'Click' THEN recipient_email || '|' || ses_message_id END)")
    ) || Array.new(8, 0)

    @sent_count, @delivered_count, @bounce_count, @complaint_count,
      @open_count, @click_count, @unique_open_count, @unique_click_count = row.map(&:to_i)
  end

  def build_chart_data(events, range_start, range_end)
    rows = events
      .where(event_type: [ :send, :delivery, :bounce ])
      .group(Arel.sql("DATE(event_at)"))
      .pluck(
        Arel.sql("DATE(event_at)"),
        Arel.sql("SUM(CASE WHEN event_type = 'Send' THEN 1 ELSE 0 END)"),
        Arel.sql("SUM(CASE WHEN event_type = 'Delivery' THEN 1 ELSE 0 END)"),
        Arel.sql("SUM(CASE WHEN event_type = 'Bounce' THEN 1 ELSE 0 END)")
      )

    by_date = rows.each_with_object({}) do |(day, sent, delivered, bounced), hash|
      key = day.is_a?(Date) ? day : Date.parse(day.to_s)
      hash[key] = { sent: sent.to_i, delivered: delivered.to_i, bounced: bounced.to_i }
    end

    dates = (range_start..range_end).to_a
    series = %i[sent delivered bounced].map do |key|
      values = dates.map { |date| by_date.dig(date, key) || 0 }
      { key:, values: }
    end

    { dates:, series: }
  end

  def source_index_stats(sources)
    source_ids = sources.map(&:id)
    last_30_days = 30.days.ago.beginning_of_day..Time.current.end_of_day

    counts = Event.where(source_id: source_ids, event_at: last_30_days)
      .group(:source_id)
      .pluck(
        Arel.sql("source_id"),
        Arel.sql("SUM(CASE WHEN event_type = 'Send' THEN 1 ELSE 0 END)"),
        Arel.sql("SUM(CASE WHEN event_type = 'Bounce' THEN 1 ELSE 0 END)")
      ).to_h { |source_id, sent, bounced| [ source_id, { sent: sent.to_i, bounced: bounced.to_i } ] }

    last_event_at = Event.where(source_id: source_ids).group(:source_id).maximum(:event_at)

    source_ids.index_with do |id|
      sent = counts.dig(id, :sent) || 0
      bounced = counts.dig(id, :bounced) || 0
      {
        sent_30d: sent,
        bounce_rate: sent.positive? ? (bounced.to_f / sent * 100) : nil,
        last_event_at: last_event_at[id]
      }
    end
  end

  def bounce_breakdown(events)
    events.event_type_bounce.group(:bounce_type).count.transform_keys do |bounce_type|
      bounce_type.presence || "Unknown"
    end
  end
end
