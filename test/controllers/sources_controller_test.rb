require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
  end

  # Characterizes the dashboard numbers so the stats extraction provably
  # preserves behavior: 4 sends, 3 deliveries, 2 bounces (Permanent +
  # Transient), 1 complaint, 2 opens by one recipient on one message
  # (1 unique), 1 click.
  test "dashboard renders counts, rates, unique opens, and bounce breakdown" do
    source = accounts(:instance).sources.create!(name: "Charted")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 2.days.ago)

    record = ->(type, recipient, at, bounce_type: nil, bounce_subtype: nil) {
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: type,
        event_at: at, recipient_email: recipient, bounce_type: bounce_type, bounce_subtype: bounce_subtype)
    }

    4.times { |i| record.call("Send", "r#{i}@example.com", 2.days.ago + i.minutes) }
    3.times { |i| record.call("Delivery", "r#{i}@example.com", 2.days.ago + (10 + i).minutes) }
    record.call("Bounce", "r3@example.com", 2.days.ago + 20.minutes, bounce_type: "Permanent", bounce_subtype: "General")
    record.call("Bounce", "r2@example.com", 2.days.ago + 21.minutes, bounce_type: "Transient", bounce_subtype: "MailboxFull")
    record.call("Complaint", "r1@example.com", 2.days.ago + 22.minutes)
    record.call("Open", "r0@example.com", 1.day.ago)
    record.call("Open", "r0@example.com", 1.day.ago + 5.minutes)
    record.call("Click", "r0@example.com", 1.day.ago + 6.minutes)

    get source_path(source)

    assert_response :success
    assert_match "50.0% bounced", response.body       # 2 bounces / 4 sends
    assert_match "25.0% opened", response.body        # 1 unique open / 4 sends
    assert_match "25.00% rate", response.body         # 1 unique click / 4 sends
    assert_match "Hard bounce", response.body
    assert_match "Soft bounce", response.body
    assert_select "li", text: /Mailbox full\s*1/
    assert_select "li", text: /General\s*1/
    assert_select "h3", text: "Repeat bouncers", count: 0 # nobody bounced twice
    assert_select "div", text: "4"                    # sent count stat tile
  end

  test "dashboard lists repeat bouncers linking to their bounce activity" do
    source = accounts(:instance).sources.create!(name: "Drip")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 2.days.ago)
    3.times do |i|
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Bounce",
        event_at: 2.days.ago + i.hours, recipient_email: "full@example.com", bounce_type: "Transient", bounce_subtype: "MailboxFull")
    end
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Bounce",
      event_at: 1.day.ago, recipient_email: "once@example.com", bounce_type: "Permanent", bounce_subtype: "General")

    get source_path(source)

    assert_response :success
    assert_select "h3", text: "Repeat bouncers"
    assert_select "li", text: /full@example\.com\s*3 bounces/
    assert_select "a[href=?]", source_events_path(source, query: "full@example.com", event_types: [ "bounce" ])
    assert_select "li", text: /once@example\.com/, count: 0
  end

  test "dashboard frames bounce and complaint rates against AWS thresholds" do
    source = accounts(:instance).sources.create!(name: "Healthy")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 2.days.ago)
    100.times do |i|
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
        event_at: 2.days.ago, recipient_email: "r#{i}@example.com")
    end
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Bounce",
      event_at: 2.days.ago, recipient_email: "r0@example.com", bounce_type: "Permanent")

    get source_path(source)

    assert_response :success
    assert_match "AWS reviews at 5%, may pause at 10%", response.body
    assert_match "AWS reviews at 0.1%, may pause at 0.5%", response.body
    assert_select "[role=meter][aria-valuenow='1.0'][aria-valuemax='10.0']"
  end

  test "dashboard flags a rate above the AWS review level" do
    source = accounts(:instance).sources.create!(name: "Bouncy")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 2.days.ago)
    10.times do |i|
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
        event_at: 2.days.ago, recipient_email: "r#{i}@example.com")
    end
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Bounce",
      event_at: 2.days.ago, recipient_email: "r0@example.com", bounce_type: "Permanent")

    get source_path(source)

    assert_match "Above the 10% where AWS may pause sending", response.body
  end

  test "index shows bounce and complaint rates with the AWS thresholds" do
    source = accounts(:instance).sources.create!(name: "Listed")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Hello", sent_at: 2.days.ago)
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
      event_at: 2.days.ago, recipient_email: "r0@example.com")

    get sources_path

    assert_response :success
    assert_select "th", text: "Complaint rate"
    assert_match "AWS reviews an account at a 5% bounce or 0.1% complaint rate and may pause its sending at 10% or 0.5%.", response.body
    assert_select "[role=meter][aria-valuemax='0.5']"
  end

  test "dashboard renders with zero events" do
    source = accounts(:instance).sources.create!(name: "Empty")

    get source_path(source)

    assert_response :success
  end

  test "overview empty state follows the recorded first event, not live messages" do
    source = accounts(:instance).sources.create!(name: "Quiet")

    get source_path(source)
    assert_select "p", text: "Finish setup to start receiving events"
    assert_select "a[href='#{source_setup_path(source)}']", text: /setup/i, minimum: 2 # tab + empty state

    source.update!(subscribed_at: Time.current)
    get source_path(source)
    assert_select "p", text: "SNS connected"
    assert_match "quiet-ses", response.body
    assert_select "p", text: "Finish setup to start receiving events", count: 0

    source.update!(first_event_at: 1.day.ago)
    get source_path(source)
    assert_equal 0, source.messages.count
    assert_select "p", text: "Finish setup to start receiving events", count: 0
    assert_select "p", text: "SNS connected", count: 0
    assert_select "a[href='#{source_setup_path(source)}']", count: 1 # the tab only
  end
end
