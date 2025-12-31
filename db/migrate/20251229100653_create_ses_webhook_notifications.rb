class CreateSesWebhookNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :ses_webhook_notifications do |t|
      t.string :sns_message_id, null: false
      t.string :sns_type, null: false
      t.datetime :sns_timestamp, null: false
      t.json :raw_payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :ses_webhook_notifications, :sns_message_id, unique: true
    add_index :ses_webhook_notifications, :processed_at
  end
end
