class Source < ApplicationRecord
  include Colors
  include RetentionPolicy

  has_many :messages, dependent: :destroy
  has_many :events, through: :messages

  validates :name, presence: true
  validates :token, uniqueness: true

  before_validation :generate_token, on: :create

  scope :alphabetically, -> { order(name: :asc) }

  private

  def generate_token
    self.token ||= SecureRandom.uuid
  end
end
