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
      base = base_filtered_scope(params)

      {
        event_types: base.group(:event_type).count,
        bounce_types: base.where(event_type: "bounce").group(:bounce_type).count
      }
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

    def date_range_from_params(params)
      preset = params[:date_range].presence || "last_30_days"

      return [ parse_date(params[:from_date]), parse_date(params[:to_date]) ] if preset == "custom"

      case preset
      when "today"
        [ Time.current.beginning_of_day, Time.current.end_of_day ]
      when "yesterday"
        [ 1.day.ago.beginning_of_day, 1.day.ago.end_of_day ]
      when "last_7_days"
        [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
      when "last_30_days"
        [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
      when "last_45_days"
        [ 45.days.ago.beginning_of_day, Time.current.end_of_day ]
      when "last_90_days"
        [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
      else
        [ nil, nil ]
      end
    end

    def parse_date(date_string)
      Time.parse(date_string) if date_string.present?
    rescue ArgumentError
      nil
    end
  end
end
