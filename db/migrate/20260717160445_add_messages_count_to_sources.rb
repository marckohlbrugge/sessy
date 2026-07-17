class AddMessagesCountToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :messages_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE sources
          SET messages_count = (SELECT COUNT(*) FROM messages WHERE messages.source_id = sources.id)
        SQL
      end
    end
  end
end
