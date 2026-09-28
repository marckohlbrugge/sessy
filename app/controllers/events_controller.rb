class EventsController < ApplicationController
  include SourceScoped

  def index
    events = filtered_events.filter_by_params(filter_params).reverse_chronologically.includes(:message)

    respond_to do |format|
      format.html do
        # Counting search matches requires an unindexable LIKE scan over the
        # whole window, so skip the chip counts entirely when searching.
        @filter_counts = cached_filter_counts unless searching?
        total = @filter_counts && Event.total_count_from(@filter_counts, filter_params)

        if total
          # The cached total can lag live rows by up to a minute, which can
          # briefly skew the page series (a missing next-page link, or an
          # empty trailing page). Accepted trade-off: rows stay live while
          # pagination avoids a multi-second COUNT on every request.
          @pagy, @events = pagy(events, limit: 50, count: total)
        else
          # No derivable total (searching, bounce subtype filters, or a
          # contended cold cache): paginate without any COUNT query.
          @pagy, @events = pagy(:countless, events, limit: 50)
        end
      end
      format.csv do
        send_data events_to_csv(events), filename: "#{@source.name.parameterize}-events-#{Date.current}.csv"
      end
    end
  end

  private

  def filtered_events
    events = @source.events
    events = events.search(params[:query]) if searching?
    events
  end

  def searching?
    params[:query].present?
  end

  # Returns cached counts, computing them on a miss. Single-flight: only one
  # request per key runs the expensive grouped count; concurrent misses return
  # nil and degrade to chips without numbers plus countless pagination, instead
  # of piling the same multi-second query onto the database.
  def cached_filter_counts
    cache_key = filter_counts_cache_key
    counts = Rails.cache.read(cache_key)
    return counts if counts
    return nil unless Rails.cache.write("#{cache_key}/lock", true, unless_exist: true, expires_in: 30.seconds)

    begin
      @source.events.filter_counts(filter_params).tap do |fresh|
        Rails.cache.write(cache_key, fresh, expires_in: 1.minute)
      end
    ensure
      Rails.cache.delete("#{cache_key}/lock")
    end
  end

  # Only validated preset names and parsed ISO 8601 dates go into the key, so
  # unrecognized params can't mint unbounded cache entries or collide.
  def filter_counts_cache_key
    preset = Event.normalized_date_range_preset(filter_params)
    key = [ "filter-counts", @source.id, preset ]
    if preset == "custom"
      from, to = Event.date_range_from_params(filter_params)
      key << (from&.iso8601 || "-") << (to&.iso8601 || "-")
    end
    key.join("/")
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
