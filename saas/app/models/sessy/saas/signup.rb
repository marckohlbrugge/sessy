# Orchestrates signup completion: a signed-in, membership-less user names
# themselves and gets a pending account with an owner membership. Plain
# ActiveModel object, not a table.
class Sessy::Saas::Signup
  include ActiveModel::Model

  attr_accessor :user, :name

  validates :name, presence: true
  validates :user, presence: true

  # Hosted accounts default to 30-day retention (U6 owns resolution/enforcement).
  HOSTED_RETENTION_DAYS = 30

  def complete
    return false unless valid?

    ActiveRecord::Base.transaction do
      account = Account.create!(name: account_name, retention_days: HOSTED_RETENTION_DAYS)
      account.memberships.create!(user: user, role: "owner")
      account
    end
  end

  private

  def account_name
    "#{name}'s Sessy"
  end
end
