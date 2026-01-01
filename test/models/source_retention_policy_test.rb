require "test_helper"

class Source::RetentionPolicyTest < ActiveSupport::TestCase
  setup do
    @source = Source.create!(name: "Test Source", retention_days: 30)
  end

  # Validation tests

  test "retention_days can be nil" do
    source = Source.new(name: "Test", retention_days: nil)
    assert source.valid?
  end

  test "retention_days must be positive" do
    source = Source.new(name: "Test", retention_days: 0)
    assert_not source.valid?
    assert_includes source.errors[:retention_days], "must be greater than 0"
  end

  test "retention_days rejects negative values" do
    source = Source.new(name: "Test", retention_days: -5)
    assert_not source.valid?
  end

  test "retention_days must be an integer" do
    source = Source.new(name: "Test", retention_days: 30.5)
    assert_not source.valid?
    assert_includes source.errors[:retention_days], "must be an integer"
  end

  # Scope tests

  test "with_retention_policy includes sources with retention_days set" do
    source_with_policy = Source.create!(name: "With Policy", retention_days: 30)
    source_without_policy = Source.create!(name: "Without Policy", retention_days: nil)

    results = Source.with_retention_policy

    assert_includes results, source_with_policy
    assert_not_includes results, source_without_policy
  end

  # delete_expired_data tests

  test "delete_expired_data returns 0 when retention_days is nil" do
    source = Source.create!(name: "No Retention", retention_days: nil)
    assert_equal 0, source.delete_expired_data
  end

  test "delete_expired_data returns 0 when no messages exist" do
    assert_equal 0, @source.delete_expired_data
  end

  test "delete_expired_data returns 0 when no expired messages exist" do
    create_message(@source, sent_at: 5.days.ago)

    assert_equal 0, @source.delete_expired_data
  end

  test "delete_expired_data deletes expired messages" do
    expired_message = create_message(@source, sent_at: 60.days.ago)
    recent_message = create_message(@source, sent_at: 5.days.ago)

    deleted_count = @source.delete_expired_data

    assert_equal 1, deleted_count
    assert_not Message.exists?(expired_message.id)
    assert Message.exists?(recent_message.id)
  end

  test "delete_expired_data deletes events for expired messages" do
    expired_message = create_message(@source, sent_at: 60.days.ago)
    expired_event = create_event(expired_message)

    recent_message = create_message(@source, sent_at: 5.days.ago)
    recent_event = create_event(recent_message)

    @source.delete_expired_data

    assert_not Event.exists?(expired_event.id)
    assert Event.exists?(recent_event.id)
  end

  test "delete_expired_data respects retention_days setting" do
    @source.update!(retention_days: 7)

    message_8_days_old = create_message(@source, sent_at: 8.days.ago)
    message_6_days_old = create_message(@source, sent_at: 6.days.ago)

    @source.delete_expired_data

    assert_not Message.exists?(message_8_days_old.id)
    assert Message.exists?(message_6_days_old.id)
  end

  private

  def create_message(source, sent_at:)
    Message.create!(
      source: source,
      ses_message_id: SecureRandom.uuid,
      sent_at: sent_at
    )
  end

  def create_event(message)
    Event.create!(
      message: message,
      ses_message_id: message.ses_message_id,
      event_type: "send",
      event_at: message.sent_at,
      recipient_email: "test@example.com"
    )
  end
end
