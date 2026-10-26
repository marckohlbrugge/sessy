class AddBounceSubtypeToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :bounce_subtype, :string
  end
end
