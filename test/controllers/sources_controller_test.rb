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

    record = ->(type, recipient, at, bounce_type: nil) {
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: type,
        event_at: at, recipient_email: recipient, bounce_type: bounce_type)
    }

    4.times { |i| record.call("Send", "r#{i}@example.com", 2.days.ago + i.minutes) }
    3.times { |i| record.call("Delivery", "r#{i}@example.com", 2.days.ago + (10 + i).minutes) }
    record.call("Bounce", "r3@example.com", 2.days.ago + 20.minutes, bounce_type: "Permanent")
    record.call("Bounce", "r2@example.com", 2.days.ago + 21.minutes, bounce_type: "Transient")
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
    assert_select "div", text: "4"                    # sent count stat tile
  end

  test "dashboard renders with zero events" do
    source = accounts(:instance).sources.create!(name: "Empty")

    get source_path(source)

    assert_response :success
  end
end
