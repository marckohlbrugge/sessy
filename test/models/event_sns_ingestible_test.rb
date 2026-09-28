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

  private

  def mail(message_id)
    {
      "timestamp" => "2024-01-01T10:00:00.000Z",
      "messageId" => message_id,
      "source" => "sender@example.com",
      "destination" => [ "r@example.com" ],
      "commonHeaders" => { "subject" => "Hello" }
    }
  end
end
