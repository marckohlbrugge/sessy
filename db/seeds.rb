# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create a sample source
source = Source.find_or_create_by!(name: "BetaList")

puts "Created source: #{source.name} (token: #{source.token})"

source_email = "hello@example.com"

base_time = Time.zone.local(2026, 1, 1, 9, 0, 0)
event_offsets = [45, 120, 300, 540, 900]

# Create messages with events at various times
messages = [
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a1",
    sent_offset: 5.minutes,
    recipient: "alex@example.com",
    subject: "Welcome to BetaList",
    events: %w[send delivery open]
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a2",
    sent_offset: 1.hour,
    recipient: "priya@example.com",
    subject: "Your weekly product updates",
    events: %w[send delivery open click]
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a3",
    sent_offset: 3.hours,
    recipient: "sam@example.com",
    subject: "Confirm your email to stay on BetaList",
    events: %w[send delivery]
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a4",
    sent_offset: 1.day,
    recipient: "taylor@example.com",
    subject: "You are invited: early access",
    events: %w[send bounce],
    bounce_type: "Permanent"
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a5",
    sent_offset: 2.days,
    recipient: "jordan@example.com",
    subject: "We shipped new features",
    events: %w[send delivery open open click]
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a6",
    sent_offset: 1.week,
    recipient: "alex@example.com",
    subject: "Thanks for the feedback",
    events: %w[send delivery complaint]
  },
  {
    ses_message_id: "9b10b4cc-0f03-4d4d-9d8b-8f24a0b0a0a7",
    sent_offset: 2.weeks,
    recipient: "priya@example.com",
    subject: "Last chance to claim your invite",
    events: %w[send delivery open click click]
  }
]

messages.each do |message_seed|
  sent_at = base_time - message_seed[:sent_offset]

  message = Message.find_or_create_by!(ses_message_id: message_seed[:ses_message_id]) do |record|
    record.assign_attributes(
      source:,
      source_email:,
      subject: message_seed[:subject],
      sent_at:,
      mail_metadata: {
        "destination" => [message_seed[:recipient]],
        "tags" => { "environment" => "demo", "campaign" => "seed-data" }
      }
    )
  end

  message_seed[:events].each_with_index do |event_type, event_index|
    event_at = sent_at + event_offsets[event_index % event_offsets.length].seconds

    Event.find_or_create_by!(
      message:,
      ses_message_id: message_seed[:ses_message_id],
      event_type: event_type.capitalize,
      recipient_email: message_seed[:recipient],
      event_at:,
      bounce_type: message_seed[:bounce_type]
    )
  end

  puts "Created message: #{message_seed[:subject]} (#{message_seed[:events].join(' -> ')})"
end

puts
puts "Done! Visit /sources/#{source.id}/events to see the test data."
