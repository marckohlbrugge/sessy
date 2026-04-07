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

    @sent_count = @overview_events.event_type_send.count
    @sent_today_count = @source.events.event_type_send.where(event_at: Time.zone.today.all_day).count
    @delivered_count = @overview_events.event_type_delivery.count
    @bounce_count = @overview_events.event_type_bounce.count
    @complaint_count = @overview_events.event_type_complaint.count
    @open_count = @overview_events.event_type_open.count
    @click_count = @overview_events.event_type_click.count
    @unique_open_count = unique_event_count(@overview_events.event_type_open)
    @unique_click_count = unique_event_count(@overview_events.event_type_click)

    @bounce_rate = percent(@bounce_count, @sent_count)
    @complaint_rate = percent(@complaint_count, @sent_count)
    @open_rate = percent(@unique_open_count, @sent_count)
    @click_rate = percent(@unique_click_count, @sent_count)

    @chart_data = build_chart_data(@overview_events, range_start, range_end)
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

  def unique_event_count(scope)
    scope.select(:recipient_email, :ses_message_id).distinct.count
  end

  def build_chart_data(events, range_start, range_end)
    dates = (range_start..range_end).to_a
    series = {
      sent: events.event_type_send,
      delivered: events.event_type_delivery,
      bounced: events.event_type_bounce
    }.map do |key, scope|
      counts = scope.group(Arel.sql("DATE(event_at)")).count
      values = dates.map { |date| counts[date] || counts[date.to_s] || 0 }

      { key:, values: }
    end

    { dates:, series: }
  end

  def source_index_stats(sources)
    source_ids = sources.map(&:id)
    last_30_days = 30.days.ago.beginning_of_day..Time.current.end_of_day

    sent_counts = Event.joins(:message)
      .where(messages: { source_id: source_ids })
      .where(event_type: :send, event_at: last_30_days)
      .group("messages.source_id").count

    bounce_counts = Event.joins(:message)
      .where(messages: { source_id: source_ids })
      .where(event_type: :bounce, event_at: last_30_days)
      .group("messages.source_id").count

    last_event_at = Event.joins(:message)
      .where(messages: { source_id: source_ids })
      .group("messages.source_id")
      .maximum(:event_at)

    source_ids.index_with do |id|
      sent = sent_counts[id] || 0
      bounced = bounce_counts[id] || 0
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
