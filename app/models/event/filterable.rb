module Event::Filterable
  extend ActiveSupport::Concern

  included do
    scope :with_event_types, ->(types) { where(event_type: types) }
    scope :with_bounce_types, ->(types) { where(bounce_type: types.map(&:titleize)) }
    scope :between_dates, ->(from_date, to_date) {
      scope = all
      scope = scope.where("event_at >= ?", from_date) if from_date
      scope = scope.where("event_at <= ?", to_date) if to_date
      scope
    }
  end

  class_methods do
    def filter_by_params(params)
      apply_event_type_filters(base_filtered_scope(params), params)
    end

    def filter_counts(params = {})
      { event_types: base_filtered_scope(params).group(:event_type).count }
    end

    # Derives the total matching filter_by_params from already-computed
    # filter_counts, so pagination doesn't need its own COUNT query.
    # Returns nil when the total isn't derivable (bounce subtype filters).
    def total_count_from(counts, params)
      event_types = Array(params[:event_types]).reject(&:blank?)
      bounce_types = Array(params[:bounce_types]).reject(&:blank?)
      return nil if event_types.include?("bounce") && bounce_types.present?

      totals = counts[:event_types]
      return totals.values.sum if event_types.blank?

      totals.slice(*event_types).values.sum
    end

    def bounce_types
      %w[permanent transient undetermined]
    end

    def date_range_presets
      {
        "all_time" => "All time",
        "today" => "Today",
        "yesterday" => "Yesterday",
        "last_7_days" => "Last 7 days",
        "last_30_days" => "Last 30 days",
        "last_45_days" => "Last 45 days",
        "last_90_days" => "Last 90 days"
      }
    end

    # Validates the date_range param against the known presets so unrecognized
    # values can't select the all-time window (or mint junk cache keys).
    def normalized_date_range_preset(params)
      preset = params[:date_range].presence || "last_30_days"
      return preset if preset == "custom" || date_range_presets.key?(preset)

      "last_30_days"
    end

    def date_range_from_params(params)
      case normalized_date_range_preset(params)
      when "custom"
        [ parse_date(params[:from_date]), parse_date(params[:to_date]) ]
      when "all_time"
        [ nil, nil ]
      when "today"
        [ Time.current.beginning_of_day, Time.current.end_of_day ]
      when "yesterday"
        [ 1.day.ago.beginning_of_day, 1.day.ago.end_of_day ]
      when "last_7_days"
        [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
      when "last_45_days"
        [ 45.days.ago.beginning_of_day, Time.current.end_of_day ]
      when "last_90_days"
        [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
      else # last_30_days
        [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
      end
    end

    private

    def base_filtered_scope(params)
      between_dates(*date_range_from_params(params))
    end

    def apply_event_type_filters(scope, params)
      event_types = Array(params[:event_types]).reject(&:blank?)
      bounce_types = Array(params[:bounce_types]).reject(&:blank?)

      return scope if event_types.blank?

      if event_types.include?("bounce") && bounce_types.present?
        non_bounce_types = event_types - [ "bounce" ]

        if non_bounce_types.any?
          scope.where(event_type: non_bounce_types).or(scope.with_bounce_types(bounce_types))
        else
          scope.with_bounce_types(bounce_types)
        end
      else
        scope.with_event_types(event_types)
      end
    end

    def parse_date(date_string)
      Time.parse(date_string) if date_string.present?
    rescue ArgumentError
      nil
    end
  end
end
