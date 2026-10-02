class InferAwsRegionFromSnsTopicArn < ActiveRecord::Migration[8.1]
  def up
    Source.reset_column_information
    Source::AwsRegionBackfill.run
  end

  def down
    # Inferred regions are indistinguishable from chosen ones; leave them.
  end
end
