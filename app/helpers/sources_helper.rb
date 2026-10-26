module SourcesHelper
  def config_set_name(source)
    source.config_set_name
  end

  def sns_topic_name(source)
    source.sns_topic_name
  end

  def launch_stack_url(source)
    source.launch_stack_url(webhook_url: webhook_url(source_token: source.token))
  end

  # CLI snippets show the chosen region, or the same placeholder the agent
  # prompt uses until one is picked.
  def ses_region(source)
    source.aws_region_known? ? source.aws_region : "<region-code>"
  end

  def ses_region_options
    Source::SES_REGIONS.map { |code, label| [ "#{label} (#{code})", code ] }
  end

  def bounce_label(bounce_type)
    case bounce_type
    when "Permanent"
      "Hard bounce"
    when "Transient"
      "Soft bounce"
    when "Undetermined"
      "Undetermined"
    else
      bounce_type
    end
  end

  # SES bounceSubType values, worded for someone who hasn't read the SES docs.
  # "General" stays as is: SES uses it when the receiving server gave no
  # specific reason, so there is nothing more honest to call it.
  BOUNCE_REASON_LABELS = {
    "General" => "General",
    "NoEmail" => "Address doesn't exist",
    "Suppressed" => "On SES global suppression list",
    "OnAccountSuppressionList" => "On account suppression list",
    "MailboxFull" => "Mailbox full",
    "MessageTooLarge" => "Message too large",
    "ContentRejected" => "Content rejected",
    "AttachmentRejected" => "Attachment rejected",
    "Undetermined" => "Undetermined"
  }.freeze

  def bounce_reason_label(subtype)
    return "Unknown" if subtype.blank?

    BOUNCE_REASON_LABELS.fetch(subtype) { subtype.underscore.humanize }
  end

  # The subtype rows under one hard/soft bounce row, largest first.
  def bounce_reasons_for(bounce_reasons, bounce_type)
    bounce_reasons.select { |(type, _), _| type == bounce_type }
      .map { |(_, subtype), count| [ subtype, count ] }
      .sort_by { |_, count| -count }
  end
end
