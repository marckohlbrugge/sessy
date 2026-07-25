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

    account = ActiveRecord::Base.transaction do
      Account.create!(name: account_name, retention_days: HOSTED_RETENTION_DAYS).tap do |account|
        account.memberships.create!(user: user, role: "owner")
      end
    end

    # After the transaction, so the job can't race an uncommitted account.
    Sessy::Saas::AdminMailer.new_signup(account).deliver_later
    account
  end

  private

  def account_name
    "#{name}'s Sessy"
  end
end
