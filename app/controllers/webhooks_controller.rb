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
      confirm_subscription(sns_message["SubscribeURL"])
      head :ok
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
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def handle_notification(sns_message)
    Webhook.process(sns_message, source: @source)
  end

  def confirm_subscription(subscribe_url)
    uri = URI.parse(subscribe_url)
    Net::HTTP.get(uri)
    Rails.logger.info("SNS subscription confirmed: #{subscribe_url}")
  rescue => e
    Rails.logger.error("Failed to confirm SNS subscription: #{e.message}")
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
