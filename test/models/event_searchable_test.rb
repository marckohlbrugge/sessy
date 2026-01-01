require "test_helper"

class Event::SearchableTest < ActiveSupport::TestCase
  setup do
    @source = Source.create!(name: "Test Source")
    @message = Message.create!(
      source: @source,
      ses_message_id: SecureRandom.uuid,
      sent_at: Time.current,
      subject: "Welcome Email"
    )
  end

  test "search finds events by recipient email" do
    event = create_event(recipient_email: "user@example.com")

    assert_includes Event.search("user@example"), event
  end

  test "search finds events by message subject" do
    event = create_event(recipient_email: "test@example.com")

    assert_includes Event.search("Welcome"), event
  end

  test "search is case insensitive for recipient email" do
    event = create_event(recipient_email: "User@Example.com")

    assert_includes Event.search("user@example"), event
    assert_includes Event.search("USER@EXAMPLE"), event
  end

  test "search is case insensitive for subject" do
    event = create_event(recipient_email: "test@example.com")

    assert_includes Event.search("welcome"), event
    assert_includes Event.search("WELCOME"), event
  end

  test "search returns empty when no matches" do
    create_event(recipient_email: "test@example.com")

    assert_empty Event.search("nonexistent")
  end

  test "search with partial match" do
    event = create_event(recipient_email: "john.doe@company.org")

    assert_includes Event.search("john"), event
    assert_includes Event.search("company"), event
  end

  private

  def create_event(recipient_email:)
    Event.create!(
      message: @message,
      ses_message_id: @message.ses_message_id,
      event_type: "Send",
      event_at: Time.current,
      recipient_email: recipient_email
    )
  end
end
