class CreateSesMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :ses_messages do |t|
      t.string :ses_message_id, null: false
      t.string :source_email
      t.string :subject
      t.datetime :sent_at
      t.json :mail_metadata, default: {}
      t.integer :events_count, default: 0, null: false

      t.timestamps
    end

    add_index :ses_messages, :ses_message_id, unique: true
    add_index :ses_messages, :sent_at
    add_index :ses_messages, :source_email
  end
end
