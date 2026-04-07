class EventsController < ApplicationController
  include SourceScoped

  def index
    base_events = filtered_events

    respond_to do |format|
      format.html do
        @filter_counts = base_events.filter_counts(filter_params)
        events = base_events.filter_by_params(filter_params).reverse_chronologically.includes(:message)
        @pagy, @events = pagy(events, limit: 50)
      end
      format.csv do
        events = base_events.filter_by_params(filter_params).reverse_chronologically.includes(:message)
        send_data events_to_csv(events), filename: "#{@source.name.parameterize}-events-#{Date.current}.csv"
      end
    end
  end

  private

  def filtered_events
    events = @source.events
    events = events.search(params[:query]) if params[:query].present?
    events
  end

  def filter_params
    params.permit(:query, :date_range, :from_date, :to_date, event_types: [], bounce_types: [])
  end

  def events_to_csv(events)
    require "csv"
    CSV.generate do |csv|
      csv << %w[Event Recipient Subject BounceType Time]
      events.find_each do |event|
        csv << [
          event.event_type,
          event.recipient_email,
          event.message&.subject,
          event.bounce_type,
          event.event_at.iso8601
        ]
      end
    end
  end
end
