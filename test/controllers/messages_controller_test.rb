require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
    @source = sources(:betalist)
    @message = messages(:welcome)
  end

  test "show renders the reason and remote server response under bounce and delay events" do
    @message.events.create!(source: @source, ses_message_id: @message.ses_message_id, event_type: "DeliveryDelay",
      event_at: 1.hour.ago, recipient_email: "full@example.com", event_data: {
        "delayType" => "MailboxFull",
        "delayedRecipients" => [ { "emailAddress" => "full@example.com", "status" => "4.2.2", "diagnosticCode" => "smtp; 452-4.2.2 The recipient's inbox is out of storage space" } ]
      })
    @message.events.create!(source: @source, ses_message_id: @message.ses_message_id, event_type: "Bounce",
      event_at: Time.current, recipient_email: "full@example.com", bounce_type: "Transient", bounce_subtype: "MailboxFull", event_data: {
        "bounceType" => "Transient", "bounceSubType" => "MailboxFull",
        "bouncedRecipients" => [ { "emailAddress" => "full@example.com", "status" => "4.4.7", "diagnosticCode" => "smtp; 554 4.4.7 Message expired: unable to deliver in 840 minutes." } ]
      })

    get source_message_path(@source, @message)

    assert_response :success
    assert_select "span", text: "Mailbox full", count: 2
    assert_select "span", text: /4\.4\.7/
    assert_select "p", text: "554 4.4.7 Message expired: unable to deliver in 840 minutes."
    assert_select "p", text: "452-4.2.2 The recipient's inbox is out of storage space"
  end

  test "show renders plain sends and deliveries without a diagnostics block" do
    get source_message_path(@source, @message)

    assert_response :success
    assert_select "p.font-mono", count: 0
  end
end
