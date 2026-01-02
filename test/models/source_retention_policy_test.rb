require "test_helper"

class Source::RetentionPolicyTest < ActiveSupport::TestCase
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
    results = Source.with_retention_policy

    assert_includes results, sources(:wip)
    assert_not_includes results, sources(:betalist)
  end

  # delete_expired_data tests

  test "delete_expired_data returns 0 when retention_days is nil" do
    assert_equal 0, sources(:betalist).delete_expired_data
  end

  test "delete_expired_data returns 0 when no messages exist" do
    source = Source.create!(name: "Empty Source", retention_days: 30)
    assert_equal 0, source.delete_expired_data
  end

  test "delete_expired_data returns 0 when no expired messages exist" do
    source = sources(:wip)
    source.messages.where(subject: "Someone completed a todo").destroy_all

    assert_equal 0, source.delete_expired_data
  end

  test "delete_expired_data deletes expired messages" do
    source = sources(:wip)
    old_message = messages(:old_notification)
    recent_message = messages(:recent_notification)

    deleted_count = source.delete_expired_data

    assert_equal 1, deleted_count
    assert_not Message.exists?(old_message.id)
    assert Message.exists?(recent_message.id)
  end

  test "delete_expired_data deletes events for expired messages" do
    source = sources(:wip)
    old_event = events(:old_notification_send)
    recent_event = events(:recent_notification_send)

    source.delete_expired_data

    assert_not Event.exists?(old_event.id)
    assert Event.exists?(recent_event.id)
  end

  test "delete_expired_data respects retention_days setting" do
    source = sources(:wip)
    source.update!(retention_days: 7)

    message_8_days_old = Message.create!(
      source: source,
      ses_message_id: SecureRandom.uuid,
      sent_at: 8.days.ago
    )
    message_6_days_old = Message.create!(
      source: source,
      ses_message_id: SecureRandom.uuid,
      sent_at: 6.days.ago
    )

    source.delete_expired_data

    assert_not Message.exists?(message_8_days_old.id)
    assert Message.exists?(message_6_days_old.id)
  end
end
