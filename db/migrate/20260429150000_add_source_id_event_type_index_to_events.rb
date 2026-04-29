class AddSourceIdEventTypeIndexToEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    options = { if_not_exists: true }
    options[:algorithm] = :concurrently if connection.adapter_name == "PostgreSQL"

    add_index :events, [ :source_id, :event_type ], **options
  end
end
