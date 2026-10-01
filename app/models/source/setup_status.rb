# Setup progress is recorded, never derived from live data: retention deletes
# a quiet source's events and messages, so "has events right now" cannot
# distinguish a customer who went quiet from one who never finished setup.
module Source::SetupStatus
  extend ActiveSupport::Concern

  class_methods do
    # One-time stamp for sources that existed before setup status was
    # recorded. Portable correlated subqueries (no UPDATE … FROM) so it runs
    # the same on SQLite and PostgreSQL. Sources whose data already aged out
    # of retention (messages_count back at 0, nothing left) cannot be
    # recovered here and are stamped by hand.
    def backfill_first_event_at
      connection.execute(<<~SQL.squish)
        UPDATE sources
        SET first_event_at = COALESCE(
          (SELECT MIN(events.event_at) FROM events WHERE events.source_id = sources.id),
          sources.created_at
        )
        WHERE sources.first_event_at IS NULL
          AND (
            sources.messages_count > 0
            OR EXISTS (SELECT 1 FROM messages WHERE messages.source_id = sources.id)
            OR EXISTS (SELECT 1 FROM events WHERE events.source_id = sources.id)
          )
      SQL
    end
  end

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

    reload
  end

  # Conditional UPDATE rather than read-then-write so concurrent ingests keep
  # the earliest stamp.
  def record_first_event(event_at)
    self.class.where(id: id, first_event_at: nil).update_all(first_event_at: event_at)
  end
end
