class ReplaceSourceIdEventAtIndexWithCoveringIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :events, [ :source_id, :event_at, :event_type ], **index_options(:add)
    remove_index :events, name: "index_events_on_source_id_and_event_at", **index_options(:remove)
  end

  def down
    add_index :events, [ :source_id, :event_at ], **index_options(:add)
    remove_index :events, name: "index_events_on_source_id_and_event_at_and_event_type", **index_options(:remove)
  end

  private

  def index_options(action)
    options = action == :add ? { if_not_exists: true } : { if_exists: true }
    options[:algorithm] = :concurrently if connection.adapter_name == "PostgreSQL"
    options
  end
end
