require "test_helper"

class EventPayloadTest < ActiveSupport::TestCase
  MAIL_TIMESTAMP = "2024-01-01T10:00:00.000Z"
  OPEN_TIMESTAMP  = "2024-01-01T12:00:00.000Z"
  CLICK_TIMESTAMP = "2024-01-01T12:05:00.000Z"

  def open_payload
    EventPayload.new({
      "eventType" => "Open",
      "mail" => { "timestamp" => MAIL_TIMESTAMP, "messageId" => "msg1", "destination" => [ "r@example.com" ] },
      "open" => { "timestamp" => OPEN_TIMESTAMP, "userAgent" => "...", "ipAddress" => "1.2.3.4" }
    })
  end

  def click_payload
    EventPayload.new({
      "eventType" => "Click",
      "mail" => { "timestamp" => MAIL_TIMESTAMP, "messageId" => "msg1", "destination" => [ "r@example.com" ] },
      "click" => { "timestamp" => CLICK_TIMESTAMP, "userAgent" => "...", "ipAddress" => "1.2.3.4", "link" => "https://example.com" }
    })
  end

  test "Open timestamp uses open.timestamp, not mail.timestamp" do
    assert_equal Time.parse(OPEN_TIMESTAMP), open_payload.timestamp
    assert_not_equal Time.parse(MAIL_TIMESTAMP), open_payload.timestamp
  end

  test "Click timestamp uses click.timestamp, not mail.timestamp" do
    assert_equal Time.parse(CLICK_TIMESTAMP), click_payload.timestamp
    assert_not_equal Time.parse(MAIL_TIMESTAMP), click_payload.timestamp
  end
end
