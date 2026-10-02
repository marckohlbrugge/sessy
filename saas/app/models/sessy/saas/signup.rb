# Orchestrates signup completion: a signed-in, membership-less user names
# themselves and gets an approved account with an owner membership and a
# first source to set up. Plain ActiveModel object, not a table.
class Sessy::Saas::Signup
  include ActiveModel::Model

  attr_accessor :user, :name

  validates :name, presence: true
  validates :user, presence: true

  # Hosted accounts default to 30-day retention (U6 owns resolution/enforcement).
  HOSTED_RETENTION_DAYS = 30

  # Every account starts with one source so the signup redirect can land on a
  # Setup page straight away instead of on an empty sources index.
  FIRST_SOURCE_NAME = "Production"

  def complete
    return false unless valid?

    # Approved on the spot: approved_at is now the suspension switch, not an
    # admission gate (the operator nulls it by hand to stop an abusive account).
    account = ActiveRecord::Base.transaction do
      Account.create!(name: account_name, retention_days: HOSTED_RETENTION_DAYS, approved_at: Time.current).tap do |account|
        account.memberships.create!(user: user, role: "owner")
        account.sources.create!(name: FIRST_SOURCE_NAME, color: account.sources.next_available_color)
      end
    end

    # After the transaction, so the jobs can't race an uncommitted account.
    # Not Account#approve!: that would enqueue the welcome email mid-transaction.
    Sessy::Saas::AdminMailer.new_signup(account).deliver_later
    Sessy::Saas::ApprovalMailer.welcome(account).deliver_later
    account
  end

  private

  def account_name
    "#{name}'s Sessy"
  end
end
