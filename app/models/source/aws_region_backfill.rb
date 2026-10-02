# One-time fill of aws_region for sources whose SNS subscription was confirmed
# before the region was inferred from the topic ARN. Extracted from the
# migration so it is unit-testable on both adapters. Ruby rather than SQL:
# splitting the ARN differs between SQLite and PostgreSQL, the parser must
# have one owner (Source.region_from_topic_arn), and the table has tens of
# rows. A region the user chose is never touched.
module Source::AwsRegionBackfill
  def self.run
    Source.where(aws_region: nil).where.not(sns_topic_arn: nil).find_each do |source|
      region = Source.region_from_topic_arn(source.sns_topic_arn)
      Source.where(id: source.id, aws_region: nil).update_all(aws_region: region) if region
    end
  end
end
