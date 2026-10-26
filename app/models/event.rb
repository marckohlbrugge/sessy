class Event < ApplicationRecord
  include Diagnostics, Filterable, Searchable, SnsIngestible, Types

  belongs_to :message, counter_cache: :events_count
  belongs_to :source, optional: true
  belongs_to :webhook, optional: true

  validates :recipient_email, presence: true
  validates :event_at, presence: true
  validates :ses_message_id, presence: true

  normalizes :recipient_email, with: ->(email) { email.downcase.strip }

  scope :reverse_chronologically, -> { order(event_at: :desc, id: :desc) }
  scope :chronologically, -> { order(event_at: :asc, id: :asc) }
end
