require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  test "delete_orphaned removes old webhooks whose events are gone" do
    orphan = create_webhook("orphan", created_at: 2.days.ago)

    assert_difference -> { Webhook.count }, -1 do
      Webhook.delete_orphaned
    end
    assert_not Webhook.exists?(orphan.id)
  end

  test "delete_orphaned keeps webhooks that still have events" do
    webhook = create_webhook("with-events", created_at: 2.days.ago)
    events(:welcome_delivery).update!(webhook: webhook)

    assert_no_difference -> { Webhook.count } do
      Webhook.delete_orphaned
    end
  end

  test "delete_orphaned keeps recent webhooks that SNS could still redeliver" do
    create_webhook("recent", created_at: 1.hour.ago)

    assert_no_difference -> { Webhook.count } do
      Webhook.delete_orphaned
    end
  end

  private

  def create_webhook(sns_message_id, created_at:)
    Webhook.create!(
      sns_message_id: sns_message_id,
      sns_type: "Notification",
      sns_timestamp: created_at,
      raw_payload: { "MessageId" => sns_message_id },
      created_at: created_at
    )
  end
end
