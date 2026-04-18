module Event::SnsIngestible
  extend ActiveSupport::Concern

  class_methods do
    def ingest(event_payload, source:, webhook: nil)
      message = Message.find_or_create_from_event_payload(event_payload, source: source)

      event_payload.recipients.map do |recipient_email|
        create_or_find_by!(
          ses_message_id: event_payload.message_id,
          event_type: event_payload.event_type,
          recipient_email: recipient_email,
          event_at: event_payload.timestamp
        ) do |event|
          event.message = message
          event.source = source
          event.webhook = webhook
          event.event_data = event_payload.event_data
          event.raw_payload = event_payload.raw
          event.bounce_type = event_payload.event_data["bounceType"] if event_payload.event_type == "Bounce"
        end
      end
    end
  end
end
