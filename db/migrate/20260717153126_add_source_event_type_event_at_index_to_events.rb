class AddSourceEventTypeEventAtIndexToEvents < ActiveRecord::Migration[8.1]
  def change
    # if_not_exists so large installs can pre-create it with CREATE INDEX CONCURRENTLY
    add_index :events, [ :source_id, :event_type, :event_at ], if_not_exists: true
  end
end
