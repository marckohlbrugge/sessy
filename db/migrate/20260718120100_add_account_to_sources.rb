class AddAccountToSources < ActiveRecord::Migration[8.1]
  def up
    add_reference :sources, :account, foreign_key: true

    # Upgraders run migrations, so the instance account and backfill happen here.
    # Fresh installs load the schema and never execute this body; Account.instance
    # lazily creates the singleton at runtime instead.
    Source::AccountBackfill.run

    change_column_null :sources, :account_id, false
  end

  def down
    remove_reference :sources, :account, foreign_key: true
  end
end
