require "test_helper"

class EventDiagnosticsTest < ActiveSupport::TestCase
  setup do
    @message = messages(:welcome)
  end

  test "bounce picks this recipient's SMTP status and cleans up the diagnostic text" do
    event = build("Bounce", "b@example.com", bounce_subtype: "MailboxFull", event_data: {
      "bounceSubType" => "MailboxFull",
      "bouncedRecipients" => [
        { "emailAddress" => "a@example.com", "status" => "5.1.1", "diagnosticCode" => "smtp; 550 no such user" },
        { "emailAddress" => "B@example.com", "status" => "4.4.7", "diagnosticCode" => "smtp; 554 4.4.7 Message expired.<452-4.2.2 inbox is out of storage<CRLF>452 4.2.2 space - gsmtp>" }
      ]
    })

    assert event.diagnostics?
    assert_equal "MailboxFull", event.reason
    assert_equal "4.4.7", event.smtp_status
    assert_equal "554 4.4.7 Message expired.<452-4.2.2 inbox is out of storage 452 4.2.2 space - gsmtp>", event.diagnostic_code
  end

  test "delivery delay reads the delay type and delayed recipient details" do
    event = build("DeliveryDelay", "r@example.com", event_data: {
      "delayType" => "MailboxFull",
      "delayedRecipients" => [ { "emailAddress" => "r@example.com", "status" => "4.2.2", "diagnosticCode" => "smtp; 452-4.2.2 over quota" } ]
    })

    assert_equal "MailboxFull", event.reason
    assert_equal "4.2.2", event.smtp_status
    assert_equal "452-4.2.2 over quota", event.diagnostic_code
  end

  test "complaint, reject and rendering failure expose their SES reason without SMTP details" do
    complaint = build("Complaint", "r@example.com", event_data: { "complaintFeedbackType" => "abuse" })
    reject = build("Reject", "r@example.com", event_data: { "reason" => "Bad content" })
    failure = build("RenderingFailure", "r@example.com", event_data: { "errorMessage" => "Attribute 'name' is not present" })

    assert_equal "abuse", complaint.reason
    assert_equal "Bad content", reject.reason
    assert_equal "Attribute 'name' is not present", failure.reason
    assert_nil complaint.smtp_status
    assert_nil complaint.diagnostic_code
    assert complaint.diagnostics?
  end

  test "sends and deliveries have no diagnostics" do
    assert_not build("Send", "r@example.com").diagnostics?
    assert_not build("Delivery", "r@example.com", event_data: { "smtpResponse" => "250 OK" }).diagnostics?
  end

  private

  def build(type, recipient, event_data: {}, bounce_subtype: nil)
    @message.events.new(source: @message.source, ses_message_id: @message.ses_message_id, event_type: type,
      event_at: Time.current, recipient_email: recipient, event_data: event_data, bounce_subtype: bounce_subtype)
  end
end
