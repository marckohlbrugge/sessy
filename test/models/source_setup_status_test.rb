require "test_helper"

class Source::SetupStatusTest < ActiveSupport::TestCase
  test "setup_status follows the recorded columns" do
    source = Source.new(name: "Fresh")
    assert_equal :waiting, source.setup_status

    source.subscribed_at = Time.current
    assert_equal :connected, source.setup_status

    source.first_event_at = Time.current
    assert_equal :complete, source.setup_status
  end

  test "setup_status is complete when only first_event_at is known" do
    source = Source.new(name: "Legacy", first_event_at: 1.day.ago)
    assert_equal :complete, source.setup_status
  end

  test "record_first_event stamps once and keeps the earliest value" do
    source = accounts(:instance).sources.create!(name: "Stamped")

    source.record_first_event(Time.utc(2026, 9, 1))
    assert_equal Time.utc(2026, 9, 1), source.reload.first_event_at

    source.record_first_event(Time.utc(2026, 9, 2))
    assert_equal Time.utc(2026, 9, 1), source.reload.first_event_at
  end

  test "record_first_event keeps the first stamp when two stale instances race" do
    source = accounts(:instance).sources.create!(name: "Raced")
    first = Source.find(source.id)
    second = Source.find(source.id)

    first.record_first_event(Time.utc(2026, 9, 1))
    second.record_first_event(Time.utc(2026, 9, 2))

    assert_equal Time.utc(2026, 9, 1), source.reload.first_event_at
  end

  test "record_subscription_confirmed keeps the first subscribed_at and the latest topic" do
    source = accounts(:instance).sources.create!(name: "Confirmed")

    travel_to Time.utc(2026, 9, 1) do
      source.record_subscription_confirmed("arn:aws:sns:us-east-1:1:first")
    end
    travel_to Time.utc(2026, 9, 2) do
      source.record_subscription_confirmed("arn:aws:sns:us-east-1:1:second")
    end

    source.reload
    assert_equal Time.utc(2026, 9, 1), source.subscribed_at
    assert_equal "arn:aws:sns:us-east-1:1:second", source.sns_topic_arn
  end

  test "backfill stamps sources that have messages but no events with created_at" do
    source = accounts(:instance).sources.create!(name: "Aged out", created_at: 10.days.ago)
    source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "x", sent_at: 5.days.ago)
    assert_equal 1, source.reload.messages_count

    Source::FirstEventBackfill.run

    assert_in_delta 10.days.ago, source.reload.first_event_at, 2
  end

  test "backfill uses the earliest event when events survive" do
    source = accounts(:instance).sources.create!(name: "Active")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "x", sent_at: 3.days.ago)
    [ 3.days.ago, 1.day.ago ].each do |at|
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send", event_at: at, recipient_email: "r@example.com")
    end

    Source::FirstEventBackfill.run

    assert_in_delta 3.days.ago, source.reload.first_event_at, 2
  end

  test "backfill uses surviving events even when messages_count is zero" do
    source = accounts(:instance).sources.create!(name: "Counter drifted")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "x", sent_at: 2.days.ago)
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send", event_at: 2.days.ago, recipient_email: "r@example.com")
    Source.where(id: source.id).update_all(messages_count: 0)

    Source::FirstEventBackfill.run

    assert_in_delta 2.days.ago, source.reload.first_event_at, 2
  end

  test "backfill leaves sources with no messages and no events untouched" do
    source = accounts(:instance).sources.create!(name: "Never sent")

    Source::FirstEventBackfill.run

    assert_nil source.reload.first_event_at
  end

  test "backfill is idempotent and never overwrites an existing stamp" do
    source = accounts(:instance).sources.create!(name: "Already stamped", first_event_at: Time.utc(2026, 1, 1))
    source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "x", sent_at: 1.day.ago)

    Source::FirstEventBackfill.run
    Source::FirstEventBackfill.run

    assert_equal Time.utc(2026, 1, 1), source.reload.first_event_at
  end
end
