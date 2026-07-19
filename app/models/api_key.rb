class ApiKey < ApplicationRecord
  TOKEN_PREFIX = "sessy_"
  LAST_USED_PRECISION = 1.hour

  belongs_to :account

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  # The plaintext token only exists in memory on the instance that generated
  # it; the database stores its digest. Multi-tenant backups and read-only DB
  # sessions must never be a key-exfiltration surface.
  attr_reader :token

  def self.find_by_token(token)
    find_by(token_digest: digest(token)) if token.present?
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def track_usage
    return if last_used_at.present? && last_used_at.after?(LAST_USED_PRECISION.ago)

    update_column :last_used_at, Time.current
  end

  private

  def generate_token
    @token ||= "#{TOKEN_PREFIX}#{SecureRandom.base58(30)}"
    self.token_digest ||= self.class.digest(@token)
    self.token_prefix ||= @token.first(TOKEN_PREFIX.length + 4)
  end
end
