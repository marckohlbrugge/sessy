# Orchestrates signup completion: a signed-in, membership-less user names
# themselves and gets an approved account with an owner membership and a
# first source to set up. Plain ActiveModel object, not a table.
class Sessy::Saas::Signup
  include ActiveModel::Model

  attr_accessor :user, :name
  attr_reader :source

  validates :name, presence: true
  validates :user, presence: true

  # Hosted accounts default to 30-day retention (U6 owns resolution/enforcement).
  HOSTED_RETENTION_DAYS = 30

  # Every account starts with one source so the signup redirect can land on a
  # Setup page straight away instead of on an empty sources index.
  FIRST_SOURCE_NAME = "Production"

  def complete
    return false unless valid?

    created = false
    account = ActiveRecord::Base.transaction do
      # Serialize completions per user: a double-submitted form (or two tabs)
      # otherwise passes the controller's membership check twice and creates
      # two accounts. The second caller waits on the row lock, then finds the
      # account the first one made.
      user.lock!
      user.accounts.order(:id).first || begin
        created = true
        create_account
      end
    end
    @source = account.sources.order(:id).first

    if created
      # After the transaction, so the jobs can't race an uncommitted account.
      # Not Account#approve!: that would enqueue the welcome email mid-transaction.
      Sessy::Saas::AdminMailer.new_signup(account).deliver_later
      Sessy::Saas::ApprovalMailer.welcome(account).deliver_later
    end
    account
  end

  private

  # Approved on the spot: approved_at is the suspension switch, not an
  # admission gate (the operator nulls it by hand to stop an abusive account).
  def create_account
    Account.create!(name: account_name, retention_days: HOSTED_RETENTION_DAYS, approved_at: Time.current).tap do |account|
      account.memberships.create!(user: user, role: "owner")
      # The first colour in the palette is what next_available_color picks
      # for an account with no sources yet; skip the query.
      account.sources.create!(name: FIRST_SOURCE_NAME, color: Source::Colors::ALL.first)
    end
  end

  def account_name
    "#{name}'s Sessy"
  end
end
