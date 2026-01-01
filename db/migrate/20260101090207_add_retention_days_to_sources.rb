class AddRetentionDaysToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :retention_days, :integer
  end
end
