# Create a demo source
source = Source.find_or_create_by!(name: "Demo App") do |s|
  s.color = "purple"
end

puts "Created source: #{source.name} (token: #{source.token})"

# Sample email addresses
recipients = %w[
  alice@example.com
  bob@example.com
  carol@example.com
  dave@example.com
  eve@example.com
]

subjects = [
  "Welcome to Demo App!",
  "Your weekly digest",
  "Password reset requested",
  "New comment on your post",
  "Invoice #12345",
  "Shipping confirmation",
  "Your subscription is expiring"
]

# Create messages with events at various times
[
  { ago: 5.minutes, events: %w[send delivery open] },
  { ago: 1.hour, events: %w[send delivery open click] },
  { ago: 3.hours, events: %w[send delivery] },
  { ago: 1.day, events: %w[send bounce], bounce_type: "Permanent" },
  { ago: 2.days, events: %w[send delivery open open click] },
  { ago: 1.week, events: %w[send delivery complaint] },
  { ago: 2.weeks, events: %w[send delivery open click click] }
].each_with_index do |config, index|
  sent_at = config[:ago].ago
  recipient = recipients.sample
  subject = subjects[index % subjects.length]
  ses_message_id = SecureRandom.uuid

  message = Message.find_or_create_by!(ses_message_id: ses_message_id) do |m|
    m.source = source
    m.source_email = "noreply@demo-app.example.com"
    m.subject = subject
    m.sent_at = sent_at
    m.mail_metadata = {
      "destination" => [ recipient ],
      "tags" => { "environment" => "demo", "campaign" => "seed-data" }
    }
  end

  event_time = sent_at
  config[:events].each do |event_type|
    event_time += rand(1..30).seconds

    Event.find_or_create_by!(
      message: message,
      ses_message_id: ses_message_id,
      event_type: event_type.capitalize,
      recipient_email: recipient,
      event_at: event_time
    ) do |e|
      e.bounce_type = config[:bounce_type] if event_type == "bounce" && config[:bounce_type]
    end
  end

  puts "Created message: #{subject} (#{config[:events].join(' -> ')})"
end

puts "\nDone! Visit /sources/#{source.id}/events to see the test data."
