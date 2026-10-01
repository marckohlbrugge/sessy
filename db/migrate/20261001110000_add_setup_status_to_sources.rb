class AddSetupStatusToSources < ActiveRecord::Migration[8.1]
  def up
    add_column :sources, :subscribed_at, :datetime
    add_column :sources, :first_event_at, :datetime
    add_column :sources, :sns_topic_arn, :string

    Source.reset_column_information
    Source::FirstEventBackfill.run
  end

  def down
    remove_column :sources, :sns_topic_arn
    remove_column :sources, :first_event_at
    remove_column :sources, :subscribed_at
  end
end
