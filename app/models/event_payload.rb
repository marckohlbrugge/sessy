class EventPayload
  # SES publishes "Rendering Failure" with a space; Event::Types stores it as
  # "RenderingFailure". Every other SES event type already matches the enum.
  EVENT_TYPE_ALIASES = { "Rendering Failure" => "RenderingFailure" }.freeze

  attr_reader :raw

  def initialize(payload_hash)
    @raw = payload_hash
  end

  def event_type
    EVENT_TYPE_ALIASES.fetch(raw["eventType"], raw["eventType"])
  end

  def message_id
    raw.dig("mail", "messageId")
  end

  def mail_data
    raw["mail"]
  end

  def source_email
    mail_data["source"]
  end

  def subject
    mail_data.dig("commonHeaders", "subject")
  end

  def sent_at
    mail_data["timestamp"] ? parse_time(mail_data["timestamp"]) : nil
  end

  def timestamp
    case event_type
    when "Bounce"
      parse_time(raw.dig("bounce", "timestamp"))
    when "Complaint"
      parse_time(raw.dig("complaint", "timestamp"))
    when "Delivery"
      parse_time(raw.dig("delivery", "timestamp"))
    when "DeliveryDelay"
      parse_time(raw.dig("deliveryDelay", "timestamp"))
    when "Subscription"
      parse_time(raw.dig("subscription", "timestamp"))
    when "Open"
      parse_time(raw.dig("open", "timestamp"))
    when "Click"
      parse_time(raw.dig("click", "timestamp"))
    else
      parse_time(raw.dig("mail", "timestamp"))
    end
  end

  def recipients
    case event_type
    when "Bounce"
      raw.dig("bounce", "bouncedRecipients")&.map { |r| r["emailAddress"] } || []
    when "Complaint"
      raw.dig("complaint", "complainedRecipients")&.map { |r| r["emailAddress"] } || []
    when "Delivery"
      raw.dig("delivery", "recipients") || []
    when "DeliveryDelay"
      raw.dig("deliveryDelay", "delayedRecipients")&.map { |r| r["emailAddress"] } || []
    else
      raw.dig("mail", "destination") || []
    end
  end

  def event_data
    case event_type
    when "Bounce"
      raw["bounce"]
    when "Complaint"
      raw["complaint"]
    when "Delivery"
      raw["delivery"]
    when "DeliveryDelay"
      raw["deliveryDelay"]
    when "RenderingFailure"
      raw["failure"]
    when "Reject"
      raw["reject"]
    when "Subscription"
      raw["subscription"]
    when "Open"
      raw["open"]
    when "Click"
      raw["click"]
    else
      {}
    end
  end

  private

  def parse_time(timestamp_string)
    Time.parse(timestamp_string)
  rescue
    Time.current
  end
end
