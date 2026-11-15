require "test_helper"

class DeleteExpiredDataJobTest < ActiveJob::TestCase
  test "deletes the raw webhook payloads of expired events" do
    source = sources(:wip)
    old_message = messages(:old_notification)
    webhook = Webhook.create!(
      sns_message_id: "expired",
      sns_type: "Notification",
      sns_timestamp: old_message.sent_at,
      raw_payload: { "MessageId" => "expired" },
      created_at: old_message.sent_at
    )
    old_message.events.update_all(webhook_id: webhook.id)
    assert old_message.events.exists?

    DeleteExpiredDataJob.perform_now

    assert_not Message.exists?(old_message.id)
    assert_not Webhook.exists?(webhook.id)
    assert source.reload.messages.exists?
  end
end
