require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  SUBSCRIBE_URL = "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn:aws:sns:us-east-1:123456789012:betalist-ses-events&Token=abc"
  TOPIC_ARN = "arn:aws:sns:us-east-1:123456789012:betalist-ses-events"

  setup do
    @source = sources(:betalist)
    @original_fetcher = SnsSubscriptionConfirmation.fetcher
    SnsSubscriptionConfirmation.fetcher = ->(uri) { flunk "unexpected outbound request to #{uri}" }
  end

  teardown do
    SnsSubscriptionConfirmation.fetcher = @original_fetcher
  end

  # --- SubscriptionConfirmation ---

  test "successful confirmation sets subscribed_at once and records the topic" do
    sns_responds 200, confirmed_body

    post_sns subscription_confirmation
    assert_response :ok

    @source.reload
    assert @source.subscribed_at.present?
    assert_equal TOPIC_ARN, @source.sns_topic_arn
    first_subscribed_at = @source.subscribed_at

    travel 1.hour do
      post_sns subscription_confirmation
      assert_response :ok
    end

    assert_equal first_subscribed_at, @source.reload.subscribed_at
  end

  test "a later confirmation from a different topic replaces sns_topic_arn but keeps subscribed_at" do
    sns_responds 200, confirmed_body
    post_sns subscription_confirmation
    first_subscribed_at = @source.reload.subscribed_at

    other_topic = "arn:aws:sns:us-east-1:999999999999:someone-elses-topic"
    travel 1.hour do
      post_sns subscription_confirmation(topic_arn: other_topic)
      assert_response :ok
    end

    @source.reload
    assert_equal other_topic, @source.sns_topic_arn
    assert_equal first_subscribed_at, @source.subscribed_at
  end

  test "confirmation responses without a SubscriptionArn or with an error status return 5xx and set nothing" do
    [ [ 200, "<ConfirmSubscriptionResponse></ConfirmSubscriptionResponse>" ], [ 400, "<Error/>" ], [ 500, "" ] ].each do |status, body|
      sns_responds status, body

      post_sns subscription_confirmation
      assert_response :service_unavailable, "expected 503 for upstream #{status}"
    end

    @source.reload
    assert_nil @source.subscribed_at
    assert_nil @source.sns_topic_arn
  end

  test "a confirmation timeout returns 5xx and sets nothing" do
    SnsSubscriptionConfirmation.fetcher = ->(_uri) { raise Net::OpenTimeout }

    post_sns subscription_confirmation
    assert_response :service_unavailable

    assert_nil @source.reload.subscribed_at
  end

  test "SubscribeURLs outside SNS are rejected before any request" do
    [
      "https://example.com/?Action=ConfirmSubscription",
      "http://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription",
      "https://sns.us-east-1.amazonaws.com.evil.example/?Action=ConfirmSubscription",
      "not a url",
      nil
    ].each do |url|
      post_sns subscription_confirmation(subscribe_url: url)
      assert_response :bad_request, "expected 400 for #{url.inspect}"
    end

    assert_nil @source.reload.subscribed_at
  end

  test "confirmation for an unapproved account returns 404 and sets nothing" do
    account = Account.create!(name: "Pending")
    source = account.sources.create!(name: "Pending source")

    post webhook_path(source.token), params: subscription_confirmation.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :not_found

    assert_nil source.reload.subscribed_at
  end

  # --- Notification ---

  test "first notification stamps first_event_at with the event timestamp and later ones leave it" do
    assert_nil @source.first_event_at

    post_sns notification(message_id: "msg-first", timestamp: "2026-09-01T10:00:00.000Z")
    assert_response :ok
    assert_equal Time.utc(2026, 9, 1, 10), @source.reload.first_event_at

    post_sns notification(message_id: "msg-second", timestamp: "2026-09-02T10:00:00.000Z")
    assert_response :ok
    assert_equal Time.utc(2026, 9, 1, 10), @source.reload.first_event_at

    # Redelivery of the same SNS MessageId takes the idempotent path.
    2.times do
      post_sns notification(message_id: "msg-first", timestamp: "2026-08-01T10:00:00.000Z", sns_message_id: "sns-first")
      assert_response :ok
    end
    assert_equal Time.utc(2026, 9, 1, 10), @source.reload.first_event_at
  end

  private

  def post_sns(message)
    post webhook_path(@source.token), params: message.to_json, headers: { "CONTENT_TYPE" => "application/json" }
  end

  def subscription_confirmation(subscribe_url: SUBSCRIBE_URL, topic_arn: TOPIC_ARN)
    {
      "Type" => "SubscriptionConfirmation",
      "MessageId" => SecureRandom.uuid,
      "Token" => "abc",
      "TopicArn" => topic_arn,
      "Message" => "You have chosen to subscribe to the topic #{topic_arn}.",
      "SubscribeURL" => subscribe_url,
      "Timestamp" => Time.current.iso8601
    }
  end

  def notification(message_id:, timestamp:, sns_message_id: SecureRandom.uuid)
    {
      "Type" => "Notification",
      "MessageId" => sns_message_id,
      "TopicArn" => TOPIC_ARN,
      "Timestamp" => Time.current.iso8601,
      "Message" => {
        "eventType" => "Send",
        "mail" => {
          "timestamp" => timestamp,
          "messageId" => message_id,
          "source" => "sender@example.com",
          "destination" => [ "r@example.com" ],
          "commonHeaders" => { "subject" => "Hello" }
        }
      }.to_json
    }
  end

  def confirmed_body
    "<ConfirmSubscriptionResponse><ConfirmSubscriptionResult><SubscriptionArn>#{TOPIC_ARN}:deadbeef</SubscriptionArn></ConfirmSubscriptionResult></ConfirmSubscriptionResponse>"
  end

  def sns_responds(status, body)
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s).new("1.1", status.to_s, "")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)

    SnsSubscriptionConfirmation.fetcher = ->(_uri) { response }
  end
end
