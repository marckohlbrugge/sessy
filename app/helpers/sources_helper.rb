module SourcesHelper
  def config_set_name(source)
    source.config_set_name
  end

  def sns_topic_name(source)
    source.sns_topic_name
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
