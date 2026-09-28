class AddTrigramIndexesForSearch < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Postgres only: lets `LIKE '%term%'` on recipient emails and subjects use an
  # index. SQLite has no equivalent and keeps scanning, which is fine at the
  # sizes it's used for.
  def up
    return unless postgresql?

    enable_extension "pg_trgm"
    add_index :events, :recipient_email, name: "index_events_on_recipient_email_trgm",
      using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently, if_not_exists: true
    add_index :messages, :subject, name: "index_messages_on_subject_trgm",
      using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently, if_not_exists: true
  end

  def down
    return unless postgresql?

    remove_index :events, name: "index_events_on_recipient_email_trgm", algorithm: :concurrently, if_exists: true
    remove_index :messages, name: "index_messages_on_subject_trgm", algorithm: :concurrently, if_exists: true
  end

  private

  def postgresql?
    connection.adapter_name == "PostgreSQL"
  end
end
