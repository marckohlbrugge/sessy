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

  # CLI snippets show the chosen region, or a placeholder until one is picked.
  def ses_region(source)
    source.aws_region_known? ? source.aws_region : "<region>"
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
end
