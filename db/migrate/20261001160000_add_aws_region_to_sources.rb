class AddAwsRegionToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :aws_region, :string
  end
end
