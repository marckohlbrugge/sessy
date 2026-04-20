class DenormalizeSourceIdOnEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    unless column_exists?(:events, :source_id)
      add_reference :events, :source, foreign_key: true, index: false
    end

    while connection.select_value("SELECT 1 FROM events WHERE source_id IS NULL LIMIT 1")
      execute(<<~SQL)
        UPDATE events SET source_id = messages.source_id
        FROM messages
        WHERE events.message_id = messages.id
          AND events.source_id IS NULL
          AND events.id IN (
            SELECT id FROM events WHERE source_id IS NULL LIMIT #{BATCH_SIZE}
          )
      SQL
    end

    unless index_exists?(:events, [ :source_id, :event_at ])
      add_index :events, [ :source_id, :event_at ]
    end
  end

  def down
    remove_index :events, [ :source_id, :event_at ] if index_exists?(:events, [ :source_id, :event_at ])
    remove_reference :events, :source, foreign_key: true if column_exists?(:events, :source_id)
  end
end
