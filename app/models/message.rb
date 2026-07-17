class Message < ApplicationRecord
  belongs_to :source, counter_cache: true
  has_many :events, dependent: :destroy

  validates :ses_message_id, presence: true

  scope :reverse_chronologically, -> { order(created_at: :desc) }

  def to_param
    ses_message_id
  end

  def destination_emails
    mail_metadata.dig("destination") || []
  end

  def tags(include_ses: false)
    tags = mail_metadata.dig("tags") || {}
    tags = tags.reject { |k, _| k.start_with?("ses:") } unless include_ses
    tags
  end

  def self.find_or_create_from_event_payload(event_payload, source:)
    find_or_create_by!(ses_message_id: event_payload.message_id) do |message|
      message.source = source
      message.source_email = event_payload.source_email
      message.subject = event_payload.subject
      message.sent_at = event_payload.sent_at
      message.mail_metadata = event_payload.mail_data
    end
  end
end
