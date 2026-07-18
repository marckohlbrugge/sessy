module Source::RetentionPolicy
  extend ActiveSupport::Concern

  included do
    validates :retention_days, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

    # Reaches sources with a per-source override AND sources relying on their
    # account's default. The old per-source-only scope silently skipped the
    # account-default case, so the daily job never enforced it.
    scope :with_retention_policy, -> {
      left_joins(:account)
        .where("sources.retention_days IS NOT NULL OR accounts.retention_days IS NOT NULL")
    }
  end

  # Per source first, then the owning account. nil means keep forever.
  def effective_retention_days
    retention_days || account&.retention_days
  end

  def delete_expired_data
    days = effective_retention_days
    return 0 unless days

    expired_messages = messages.where(sent_at: ..days.days.ago)
    return 0 unless expired_messages.exists?

    Event.where(message_id: expired_messages.select(:id)).delete_all
    expired_messages.delete_all.tap do |deleted_count|
      # delete_all skips callbacks, so adjust the counter cache ourselves
      self.class.update_counters(id, messages_count: -deleted_count)
    end
  end
end
