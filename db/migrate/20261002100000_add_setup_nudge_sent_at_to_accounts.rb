class AddSetupNudgeSentAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :setup_nudge_sent_at, :datetime
  end
end
