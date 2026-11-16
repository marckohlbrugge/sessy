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

  def reputation_caption(rate)
    case rate.status
    when :pause
      "Above the #{threshold_percentage(rate.pause_at)} where AWS may pause sending"
    when :review
      "Above the #{threshold_percentage(rate.review_at)} where AWS reviews accounts"
    else
      "AWS reviews at #{threshold_percentage(rate.review_at)}, may pause at #{threshold_percentage(rate.pause_at)}"
    end
  end

  def reputation_explanation(rate)
    "AWS puts an account under review at a #{threshold_percentage(rate.review_at)} #{rate.kind} rate " \
      "and may pause its sending at #{threshold_percentage(rate.pause_at)}, measured across the whole account."
  end

  def reputation_thresholds_summary
    bounce, complaint = ReputationRate::THRESHOLDS.values_at(:bounce, :complaint)

    "AWS reviews an account at a #{threshold_percentage(bounce[:review])} bounce or " \
      "#{threshold_percentage(complaint[:review])} complaint rate and may pause its sending at " \
      "#{threshold_percentage(bounce[:pause])} or #{threshold_percentage(complaint[:pause])}."
  end

  def reputation_text_class(rate, ok: "")
    rate.ok? ? ok : "text-rose-600 dark:text-rose-400"
  end

  def threshold_percentage(percent)
    number_to_percentage(percent, strip_insignificant_zeros: true)
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
