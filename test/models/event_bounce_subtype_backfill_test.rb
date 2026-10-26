require "test_helper"

class EventBounceSubtypeBackfillTest < ActiveSupport::TestCase
  setup do
    @message = messages(:welcome)
  end

  test "fills bounce_subtype from event_data and leaves everything else alone" do
    legacy = record("Bounce", "a@example.com", event_data: { "bounceType" => "Transient", "bounceSubType" => "MailboxFull" })
    no_subtype = record("Bounce", "b@example.com", event_data: { "bounceType" => "Permanent" })
    already_set = record("Bounce", "c@example.com", bounce_subtype: "Suppressed", event_data: { "bounceSubType" => "General" })
    delivery = record("Delivery", "d@example.com", event_data: { "bounceSubType" => "MailboxFull" })

    Event::BounceSubtypeBackfill.run

    assert_equal "MailboxFull", legacy.reload.bounce_subtype
    assert_nil no_subtype.reload.bounce_subtype
    assert_equal "Suppressed", already_set.reload.bounce_subtype
    assert_nil delivery.reload.bounce_subtype
  end

  private

  def record(type, recipient, event_data:, bounce_subtype: nil)
    @message.events.create!(source: @message.source, ses_message_id: @message.ses_message_id, event_type: type,
      event_at: Time.current, recipient_email: recipient, event_data: event_data, bounce_subtype: bounce_subtype)
  end
end
