# One-time fill of bounce_subtype for bounce events ingested before the column
# existed. SES's bounceSubType has always been kept in event_data, so this is
# one JSON extraction per adapter rather than a Ruby loop: the events table
# can hold millions of rows. Batched by id so no single statement locks the
# whole table.
module Event::BounceSubtypeBackfill
  BATCH_SIZE = 10_000

  def self.run
    Event.event_type_bounce.where(bounce_subtype: nil).in_batches(of: BATCH_SIZE) do |batch|
      batch.update_all(subtype_assignment)
    end
  end

  def self.subtype_assignment
    if Event.connection.adapter_name.match?(/postg/i)
      Arel.sql("bounce_subtype = event_data->>'bounceSubType'")
    else
      Arel.sql("bounce_subtype = json_extract(event_data, '$.bounceSubType')")
    end
  end
end
