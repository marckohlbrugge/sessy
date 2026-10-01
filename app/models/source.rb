class Source < ApplicationRecord
  include Colors
  include RetentionPolicy
  include SetupStatus
  include LaunchStack

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

  # Suggested AWS resource names for the setup guide, derived from the source
  # name so they read naturally in the SES console. Names that parameterize
  # to nothing (non-Latin scripts) fall back to the source id.
  def config_set_name
    "#{resource_slug}-ses"
  end

  def sns_topic_name
    "#{resource_slug}-ses-events"
  end

  private

  def resource_slug
    name.parameterize.presence || "source-#{id}"
  end

  def generate_token
    self.token ||= SecureRandom.uuid
  end
end
