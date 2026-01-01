class DeleteExpiredDataJob < ApplicationJob
  queue_as :default

  def perform
    Source.with_retention_policy.find_each do |source|
      source.delete_expired_data
    end
  end
end
