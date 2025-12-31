class CreateSesEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :ses_events do |t|
      t.references :message, null: false, foreign_key: { to_table: :ses_messages }
      t.references :webhook_notification, foreign_key: { to_table: :ses_webhook_notifications }
      t.string :event_type, null: false
      t.string :recipient_email, null: false
      t.datetime :event_at, null: false
      t.string :ses_message_id, null: false
      t.json :event_data, default: {}
      t.json :raw_payload, default: {}
      t.string :bounce_type

      t.timestamps
    end

    add_index :ses_events,
      [ :ses_message_id, :event_type, :recipient_email, :event_at ],
      unique: true,
      name: "index_ses_events_on_deduplication_key"

    add_index :ses_events, :event_type
    add_index :ses_events, :recipient_email
    add_index :ses_events, :event_at
    add_index :ses_events, :bounce_type
  end
end
