module SetupsHelper
  SETUP_STEP_LABELS = [ "Connect SES", "Send a test email", "Done" ].freeze

  # The Setup page renders one step: the first one the recorded status has
  # not completed, or the last once complete.
  def setup_current_step(source)
    { waiting: 1, connected: 2, complete: 3 }.fetch(source.setup_status)
  end

  def setup_step_label(number)
    SETUP_STEP_LABELS.fetch(number - 1)
  end

  # The done step's one-line summary shows only what was recorded: a
  # backfilled source may know nothing but its first event.
  def setup_summary_parts(source)
    parts = []
    parts << safe_join([ "Connected", local_time(source.subscribed_at, format: "%b %-d, %Y") ], " ") if source.subscribed_at?
    parts << source.aws_region_name if source.aws_region_known?
    parts << safe_join([ "First event", local_time(source.first_event_at, format: "%b %-d, %Y") ], " ") if source.first_event_at?
    parts
  end

  def agent_instructions(source)
    Source::AgentInstructions.new(source, webhook_url: webhook_url(source_token: source.token), launch_stack_url: launch_stack_url(source))
  end
end
