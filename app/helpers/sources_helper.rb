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

  SETUP_STEP_LABELS = [ "Connect SES", "Send a test email", "Receiving events" ].freeze

  # The Setup page opens one step at a time. The current step is the first
  # one the recorded status has not completed; once complete, the last step
  # is the open one and the progress header shows all three as done.
  def setup_current_step(source)
    { waiting: 1, connected: 2, complete: 3 }.fetch(source.setup_status)
  end

  def setup_step_state(source, number)
    current = setup_current_step(source)
    if number < current then :done
    elsif number == current then :current
    else :upcoming
    end
  end

  def setup_progress_state(source, number)
    source.setup_status == :complete ? :done : setup_step_state(source, number)
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
