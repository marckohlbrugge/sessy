module Source::RetentionPolicy
  extend ActiveSupport::Concern

  included do
    validates :retention_days, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

    scope :with_retention_policy, -> { where.not(retention_days: nil) }
  end

  def delete_expired_data
    return 0 unless retention_days

    expired_messages = messages.where(sent_at: ..retention_days.days.ago)
    return 0 unless expired_messages.exists?

    Event.where(message_id: expired_messages.select(:id)).delete_all
    expired_messages.delete_all
  end
end
