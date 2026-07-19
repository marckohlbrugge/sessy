class Source < ApplicationRecord
  include Colors
  include RetentionPolicy

  belongs_to :account, default: -> { Account.instance }
  has_many :messages, dependent: :destroy
  has_many :events

  validates :name, presence: true
  validates :token, uniqueness: true

  before_validation :generate_token, on: :create

  scope :alphabetically, -> { order(name: :asc) }

  # Health stats for a set of sources, shared by the sources index and the MCP
  # list_sources tool.
  def self.overview_stats(sources)
    source_ids = sources.map(&:id)
    last_30_days = 30.days.ago.beginning_of_day..Time.current.end_of_day

    counts = Event.where(source_id: source_ids, event_at: last_30_days, event_type: %i[send bounce])
      .group(:source_id, :event_type)
      .count

    last_event_at = Event.where(source_id: source_ids).group(:source_id).maximum(:event_at)

    source_ids.index_with do |id|
      sent = counts[[ id, "send" ]] || 0
      bounced = counts[[ id, "bounce" ]] || 0
      {
        sent_30d: sent,
        bounce_rate: sent.positive? ? (bounced.to_f / sent * 100) : nil,
        last_event_at: last_event_at[id]
      }
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.uuid
  end
end
