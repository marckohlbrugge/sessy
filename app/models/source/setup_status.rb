# Setup progress is recorded, never derived from live data: retention deletes
# a quiet source's events and messages, so "has events right now" cannot
# distinguish a customer who went quiet from one who never finished setup.
module Source::SetupStatus
  def setup_status
    if first_event_at?
      :complete
    elsif subscribed_at?
      :connected
    else
      :waiting
    end
  end

  # subscribed_at is first-wins so redelivered or concurrent confirmations
  # cannot move it; sns_topic_arn is latest-wins so the status summary shows
  # whichever topic is feeding the source now (anyone holding the webhook
  # token could subscribe it to a topic of their own).
  def record_subscription_confirmed(topic_arn)
    previous_topic_arn = sns_topic_arn

    self.class.where(id: id).update_all([
      "subscribed_at = COALESCE(subscribed_at, ?), sns_topic_arn = ?", Time.current, topic_arn
    ])

    if previous_topic_arn.present? && previous_topic_arn != topic_arn
      Rails.logger.warn("Source #{id} SNS topic changed from #{previous_topic_arn} to #{topic_arn}")
    end
  end

  # The column only ever moves nil → value, so a loaded value means the DB has
  # one too and the webhook hot path skips the write. The conditional UPDATE
  # (rather than read-then-write) keeps the earliest stamp when two first
  # ingests race.
  def record_first_event(event_at)
    return if first_event_at?

    self.class.where(id: id, first_event_at: nil).update_all(first_event_at: event_at)
  end
end
