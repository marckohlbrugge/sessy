module Event::Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(term) {
      left_joins(:message).where(
        "LOWER(recipient_email) LIKE LOWER(?) OR LOWER(messages.subject) LIKE LOWER(?)",
        "%#{sanitize_sql_like(term)}%",
        "%#{sanitize_sql_like(term)}%"
      )
    }
  end
end
