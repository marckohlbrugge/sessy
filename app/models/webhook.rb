class Webhook < ApplicationRecord
  validates :sns_message_id, presence: true
  validates :sns_type, presence: true
  validates :sns_timestamp, presence: true
  # SNS redelivers a message for at most an hour, so a day-old webhook can no
  # longer be needed for deduplication.
  REDELIVERY_GRACE_PERIOD = 1.day
  DELETE_BATCH_SIZE = 10_000

  has_many :events

  validates :raw_payload, presence: true

  scope :reverse_chronologically, -> { order(created_at: :desc) }
  scope :orphaned, -> { where.missing(:events).where.not(processed_at: nil).where(created_at: ..REDELIVERY_GRACE_PERIOD.ago) }

  # Raw payloads hold the same email data as the events made from them, so
  # they go once those events are gone (retention, a deleted source). Webhooks
  # that never processed are kept: they are the only copy of that event.
  def self.delete_orphaned
    orphaned.in_batches(of: DELETE_BATCH_SIZE).delete_all
  end

  def mark_as_processed!
    update_column(:processed_at, Time.current)
  end

  def self.process(sns_message, source:)
    webhook = create_or_find_by!(sns_message_id: sns_message["MessageId"]) do |record|
      record.sns_type = sns_message["Type"]
      record.sns_timestamp = Time.parse(sns_message["Timestamp"])
      record.raw_payload = sns_message
    end

    return if webhook.processed_at?

    payload_hash = JSON.parse(sns_message["Message"])
    event_payload = EventPayload.new(payload_hash)
    Event.ingest(event_payload, source: source, webhook: webhook)
    webhook.mark_as_processed!
  end
end
