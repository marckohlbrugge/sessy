require "test_helper"

class EventSnsIngestibleTest < ActiveSupport::TestCase
  setup do
    @source = sources(:betalist)
  end

  test "ingests a Rendering Failure event as event_type_rendering_failure" do
    payload = EventPayload.new({
      "eventType" => "Rendering Failure",
      "mail" => mail("msg-rf"),
      "failure" => { "errorMessage" => "Attribute 'name' is not present", "templateName" => "welcome" }
    })

    events = Event.ingest(payload, source: @source)

    assert_equal 1, events.size
    assert events.first.event_type_rendering_failure?
    assert_equal "welcome", events.first.event_data["templateName"]
  end

  test "stores open and click details in event_data" do
    open = EventPayload.new({
      "eventType" => "Open",
      "mail" => mail("msg-oc"),
      "open" => { "timestamp" => "2024-01-01T12:00:00.000Z", "userAgent" => "Mozilla/5.0", "ipAddress" => "1.2.3.4" }
    })
    click = EventPayload.new({
      "eventType" => "Click",
      "mail" => mail("msg-oc"),
      "click" => { "timestamp" => "2024-01-01T12:05:00.000Z", "userAgent" => "Mozilla/5.0", "ipAddress" => "1.2.3.4", "link" => "https://example.com" }
    })

    open_event = Event.ingest(open, source: @source).first
    click_event = Event.ingest(click, source: @source).first

    assert_equal "Mozilla/5.0", open_event.event_data["userAgent"]
    assert_equal "https://example.com", click_event.event_data["link"]
  end

  test "records repeat opens of the same message as separate events" do
    first = EventPayload.new({
      "eventType" => "Open",
      "mail" => mail("msg-repeat"),
      "open" => { "timestamp" => "2024-01-01T12:00:00.000Z" }
    })
    second = EventPayload.new({
      "eventType" => "Open",
      "mail" => mail("msg-repeat"),
      "open" => { "timestamp" => "2024-01-01T13:00:00.000Z" }
    })

    assert_difference -> { Event.where(ses_message_id: "msg-repeat").count }, 2 do
      Event.ingest(first, source: @source)
      Event.ingest(second, source: @source)
    end
  end

  test "stamps the source's first_event_at on first ingest and leaves it afterwards" do
    source = accounts(:instance).sources.create!(name: "Fresh")
    first = EventPayload.new({ "eventType" => "Send", "mail" => mail("msg-a", timestamp: "2026-09-01T10:00:00.000Z") })
    second = EventPayload.new({ "eventType" => "Send", "mail" => mail("msg-b", timestamp: "2026-09-02T10:00:00.000Z") })

    Event.ingest(first, source: source)
    assert_equal Time.utc(2026, 9, 1, 10), source.reload.first_event_at

    Event.ingest(second, source: source)
    assert_equal Time.utc(2026, 9, 1, 10), source.reload.first_event_at
  end

  test "stamps first_event_at even when the events already exist" do
    # A crash between event creation and the stamp leaves the webhook
    # unprocessed; the SNS retry finds the events instead of creating them.
    source = accounts(:instance).sources.create!(name: "Crashed")
    payload = EventPayload.new({ "eventType" => "Send", "mail" => mail("msg-crash", timestamp: "2026-09-01T10:00:00.000Z") })

    Event.ingest(payload, source: source)
    Source.where(id: source.id).update_all(first_event_at: nil)

    assert_no_difference -> { Event.where(ses_message_id: "msg-crash").count } do
      Event.ingest(payload, source: source)
    end
    assert_equal Time.utc(2026, 9, 1, 10), source.reload.first_event_at
  end

  private

  def mail(message_id, timestamp: "2024-01-01T10:00:00.000Z")
    {
      "timestamp" => timestamp,
      "messageId" => message_id,
      "source" => "sender@example.com",
      "destination" => [ "r@example.com" ],
      "commonHeaders" => { "subject" => "Hello" }
    }
  end
end
