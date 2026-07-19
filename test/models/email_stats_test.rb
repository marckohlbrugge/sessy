require "test_helper"

class EmailStatsTest < ActiveSupport::TestCase
  setup do
    @source = accounts(:instance).sources.create!(name: "Stats")
    @message = @source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 3.days.ago)
    @range = 29.days.ago.beginning_of_day..Time.current.end_of_day
  end

  test "counts by event type, bounce breakdown, and rates" do
    4.times { |i| record "Send", "r#{i}@example.com", 3.days.ago }
    3.times { |i| record "Delivery", "r#{i}@example.com", 3.days.ago }
    record "Bounce", "r3@example.com", 3.days.ago, bounce_type: "Permanent"
    record "Bounce", "r2@example.com", 2.days.ago, bounce_type: "Transient"
    record "Bounce", "r1@example.com", 2.days.ago, bounce_type: nil
    record "Complaint", "r1@example.com", 2.days.ago

    stats = EmailStats.new(@source.events, @range)

    assert_equal 4, stats.sent_count
    assert_equal 3, stats.delivered_count
    assert_equal 3, stats.bounce_count
    assert_equal 1, stats.complaint_count
    assert_equal 75.0, stats.bounce_rate
    assert_equal 25.0, stats.complaint_rate
    assert_equal({ "Permanent" => 1, "Transient" => 1, "Unknown" => 1 }, stats.bounce_breakdown)
  end

  test "unique opens and clicks count distinct recipient and message pairs" do
    2.times { |i| record "Send", "r#{i}@example.com", 2.days.ago }
    record "Open", "r0@example.com", 1.day.ago
    record "Open", "r0@example.com", 1.day.ago + 5.minutes
    record "Open", "r1@example.com", 1.day.ago
    record "Click", "r0@example.com", 1.day.ago
    record "Click", "r0@example.com", 1.day.ago + 10.minutes

    stats = EmailStats.new(@source.events, @range)

    assert_equal 3, stats.open_count
    assert_equal 2, stats.unique_open_count
    assert_equal 2, stats.click_count
    assert_equal 1, stats.unique_click_count
    assert_equal 100.0, stats.open_rate
    assert_equal 50.0, stats.click_rate
  end

  test "daily series zero-fills days without events across the range" do
    record "Send", "r0@example.com", 2.days.ago
    record "Delivery", "r0@example.com", 2.days.ago
    record "Bounce", "r1@example.com", 1.day.ago, bounce_type: "Permanent"

    series = EmailStats.new(@source.events, @range).daily_series

    assert_equal 30, series[:dates].size
    sent = series[:series].find { |s| s[:key] == :sent }[:values]
    bounced = series[:series].find { |s| s[:key] == :bounced }[:values]
    assert_equal 30, sent.size
    assert_equal 1, sent.sum
    assert_equal 1, bounced.sum
    assert_equal 1, sent[series[:dates].index(2.days.ago.to_date)]
    assert_equal 1, bounced[series[:dates].index(1.day.ago.to_date)]
    assert_equal 0, sent.first
  end

  test "rates are zero when nothing was sent" do
    stats = EmailStats.new(@source.events, @range)

    assert_equal 0, stats.sent_count
    assert_equal 0, stats.bounce_rate
    assert_equal 0, stats.open_rate
  end

  test "events outside the range are excluded" do
    record "Send", "r0@example.com", 45.days.ago
    record "Send", "r1@example.com", 2.days.ago

    stats = EmailStats.new(@source.events, @range)

    assert_equal 1, stats.sent_count
  end

  private

  def record(type, recipient, at, bounce_type: nil)
    @message.events.create!(source: @source, ses_message_id: @message.ses_message_id, event_type: type,
      event_at: at, recipient_email: recipient, bounce_type: bounce_type)
  end
end
