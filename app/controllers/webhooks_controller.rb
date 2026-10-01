class WebhooksController < ApplicationController
  # Shared across requests so the verifier's signing-cert cache is effective.
  # A fresh instance per request re-downloads the cert from AWS every time
  # (~600ms), which dominated this endpoint's latency.
  SNS_MESSAGE_VERIFIER = Aws::SNS::MessageVerifier.new

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate
  before_action :set_source
  before_action :verify_sns_signature

  def create
    sns_message = JSON.parse(request.raw_post)

    case sns_message["Type"]
    when "SubscriptionConfirmation"
      confirm_subscription(sns_message)
    when "Notification"
      handle_notification(sns_message)
      head :ok
    when "UnsubscribeConfirmation"
      Rails.logger.info("SNS Unsubscribe confirmation received")
      head :ok
    else
      Rails.logger.warn("Unknown SNS message type: #{sns_message["Type"]}")
      head :bad_request
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse SNS message: #{e.message}")
    head :bad_request
  end

  private

  def set_source
    @source = Source.find_by!(token: params[:source_token])
    # Ingest kill switch: un-approving an account (nulling approved_at) stops
    # its sources accepting webhooks. In OSS the instance account is always
    # approved, so this is a no-op there.
    head :not_found unless @source.account.approved?
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def handle_notification(sns_message)
    Webhook.process(sns_message, source: @source)
  end

  # Answers SNS with 5xx when the confirmation did not go through so it
  # retries, instead of acknowledging a failure as success. Logs name the host
  # and topic only; the SubscribeURL carries a one-time token.
  def confirm_subscription(sns_message)
    confirmation = SnsSubscriptionConfirmation.new(sns_message["SubscribeURL"])
    topic_arn = sns_message["TopicArn"]

    unless confirmation.sns_url?
      Rails.logger.warn("Rejected SNS SubscribeURL on host #{confirmation.host.inspect} for source #{@source.id}")
      return head :bad_request
    end

    if confirmation.confirm
      @source.record_subscription_confirmed(topic_arn)
      Rails.logger.info("SNS subscription confirmed for source #{@source.id} via #{confirmation.host} (#{topic_arn})")
      head :ok
    else
      Rails.logger.error("SNS subscription confirmation failed for source #{@source.id} via #{confirmation.host} (#{topic_arn})")
      head :service_unavailable
    end
  end

  def verify_sns_signature
    return true if Rails.env.local?

    message_body = request.raw_post

    unless SNS_MESSAGE_VERIFIER.authentic?(message_body)
      Rails.logger.error("SNS signature verification failed")
      head :forbidden
      return false
    end

    true
  rescue => e
    Rails.logger.error("SNS signature verification error: #{e.message}")
    head :forbidden
    false
  end
end
