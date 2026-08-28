require "test_helper"

class EventFilterableTest < ActiveSupport::TestCase
  test "total_count_from sums all types when no event type filter" do
    counts = { event_types: { "send" => 3, "delivery" => 2, "bounce" => 1 } }

    assert_equal 6, Event.total_count_from(counts, {})
  end

  test "total_count_from sums only the selected event types" do
    counts = { event_types: { "send" => 3, "delivery" => 2, "bounce" => 1 } }

    assert_equal 4, Event.total_count_from(counts, { event_types: [ "send", "bounce", "" ] })
  end

  test "total_count_from ignores selected types with no events" do
    counts = { event_types: { "send" => 3 } }

    assert_equal 3, Event.total_count_from(counts, { event_types: [ "send", "click" ] })
  end

  test "total_count_from is nil when bounce subtypes are filtered" do
    counts = { event_types: { "send" => 3, "bounce" => 2 } }

    assert_nil Event.total_count_from(counts, { event_types: [ "bounce" ], bounce_types: [ "permanent" ] })
  end

  test "normalized_date_range_preset keeps known presets and custom" do
    assert_equal "last_7_days", Event.normalized_date_range_preset({ date_range: "last_7_days" })
    assert_equal "custom", Event.normalized_date_range_preset({ date_range: "custom" })
  end

  test "normalized_date_range_preset falls back to last 30 days for unknown values" do
    assert_equal "last_30_days", Event.normalized_date_range_preset({})
    assert_equal "last_30_days", Event.normalized_date_range_preset({ date_range: "cache-busting-junk" })
  end

  test "date_range_from_params treats unknown presets as last 30 days, not all time" do
    from, to = Event.date_range_from_params({ date_range: "cache-busting-junk" })

    assert_in_delta 30.days.ago.beginning_of_day, from, 1.second
    assert_in_delta Time.current.end_of_day, to, 1.second
  end

  test "date_range_from_params keeps all_time unbounded" do
    assert_equal [ nil, nil ], Event.date_range_from_params({ date_range: "all_time" })
  end
end
