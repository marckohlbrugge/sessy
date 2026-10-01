# One-time stamp of first_event_at for sources that existed before setup
# status was recorded. Extracted from the migration so it is unit-testable on
# both adapters: portable correlated subqueries, no UPDATE … FROM. Sources
# whose data already aged out of retention (messages_count back at 0, nothing
# left) cannot be recovered here and are stamped by hand.
module Source::FirstEventBackfill
  def self.run
    Source.connection.execute(<<~SQL.squish)
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
