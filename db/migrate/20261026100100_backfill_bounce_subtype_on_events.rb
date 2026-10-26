class BackfillBounceSubtypeOnEvents < ActiveRecord::Migration[8.1]
  def up
    Event.reset_column_information
    Event::BounceSubtypeBackfill.run
  end

  def down
    # The column goes with the previous migration; nothing to undo here.
  end
end
