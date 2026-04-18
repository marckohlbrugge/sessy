class DenormalizeSourceIdOnEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :events, :source, foreign_key: true, index: false

    execute(<<~SQL)
      UPDATE events
      SET source_id = (SELECT source_id FROM messages WHERE messages.id = events.message_id)
      WHERE source_id IS NULL
    SQL

    add_index :events, [ :source_id, :event_at ]
  end

  def down
    remove_index :events, [ :source_id, :event_at ]
    remove_reference :events, :source, foreign_key: true
  end
end
