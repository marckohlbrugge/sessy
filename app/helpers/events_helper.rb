module EventsHelper
  def event_badge_classes(event)
    case event.event_type
    when "send"
      "bg-emerald-500/10 text-emerald-700 dark:text-emerald-400"
    when "delivery"
      "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400"
    when "bounce"
      event_bounce_badge_classes(event)
    when "complaint", "reject", "rendering_failure"
      "bg-red-500/15 text-red-700 dark:text-red-400"
    when "delivery_delay"
      "bg-amber-500/10 text-amber-700 dark:text-amber-400"
    when "subscription"
      "bg-sky-500/10 text-sky-700 dark:text-sky-400"
    when "open"
      "bg-cyan-500/10 text-cyan-700 dark:text-cyan-400"
    when "click"
      "bg-violet-500/10 text-violet-700 dark:text-violet-400"
    else
      "bg-zinc-500/10 text-zinc-700 dark:text-zinc-400"
    end
  end

  def event_label(event)
    case event.event_type
    when "send"
      "Sent"
    when "delivery"
      "Delivered"
    when "bounce"
      event_bounce_label(event)
    when "complaint"
      "Complained"
    when "reject"
      "Rejected"
    when "delivery_delay"
      "Delayed"
    when "rendering_failure"
      "Rendering Failed"
    when "subscription"
      "Subscription"
    when "open"
      "Opened"
    when "click"
      "Clicked"
    else
      event.event_type.titleize
    end
  end

  EVENT_TYPE_FILTERS = {
    "send" => "Sent",
    "delivery" => "Delivered",
    "bounce" => "Bounced",
    "complaint" => "Complained",
    "open" => "Opened",
    "click" => "Clicked",
    "delivery_delay" => "Delayed",
    "reject" => "Rejected"
  }.freeze

  def event_filter_chip_classes(event_type)
    case event_type
    when "send", "delivery"
      "border-emerald-500/30 text-emerald-700 bg-emerald-500/20 dark:text-emerald-400 dark:border-emerald-500/30 dark:bg-emerald-500/15"
    when "bounce"
      "border-red-500/30 text-red-700 bg-red-500/20 dark:text-red-400 dark:border-red-500/30 dark:bg-red-500/15"
    when "complaint", "reject"
      "border-red-500/30 text-red-700 bg-red-500/20 dark:text-red-400 dark:border-red-500/30 dark:bg-red-500/15"
    when "delivery_delay"
      "border-amber-500/30 text-amber-700 bg-amber-500/20 dark:text-amber-400 dark:border-amber-500/30 dark:bg-amber-500/15"
    when "open"
      "border-cyan-500/30 text-cyan-700 bg-cyan-500/20 dark:text-cyan-400 dark:border-cyan-500/30 dark:bg-cyan-500/15"
    when "click"
      "border-violet-500/30 text-violet-700 bg-violet-500/20 dark:text-violet-400 dark:border-violet-500/30 dark:bg-violet-500/15"
    else
      "border-zinc-500/30 text-zinc-700 bg-zinc-500/20 dark:text-zinc-400 dark:border-zinc-500/30 dark:bg-zinc-500/15"
    end
  end

  def gravatar_url(email, size: 32)
    hash = Digest::MD5.hexdigest(email.to_s.downcase)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=blank"
  end

  private

  def event_bounce_label(event)
    case event.bounce_type
    when "Permanent"
      "Hard Bounce"
    when "Transient"
      "Soft Bounce"
    else
      "Bounced"
    end
  end

  def event_bounce_badge_classes(event)
    case event.bounce_type
    when "Permanent"
      "bg-red-500/15 text-red-700 dark:text-red-400"
    when "Transient", "Undetermined"
      "bg-red-500/10 text-red-700 dark:text-red-400"
    else
      "bg-red-500/15 text-red-700 dark:text-red-400"
    end
  end
end
