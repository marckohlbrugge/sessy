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

  # Done-step summaries show only what was recorded: a backfilled source may
  # know nothing but its first event.
  def setup_connected_summary(source)
    parts = [ safe_join([ "Connected", (local_time_ago(source.subscribed_at) if source.subscribed_at?) ].compact, " ") ]
    parts << "#{source.aws_region_name} (#{source.aws_region})" if source.aws_region_known?
    parts << tag.code(source.sns_topic_arn, class: "bg-zinc-100 dark:bg-white/5 px-1 font-mono break-all") if source.sns_topic_arn.present?
    safe_join(parts, tag.span(" · ", aria: { hidden: true }, class: "text-zinc-300 dark:text-zinc-600"))
  end

  def setup_first_event_summary(source)
    safe_join([ "First event received", local_time(source.first_event_at, format: "%b %-d, %Y") ], " ") if source.first_event_at?
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
