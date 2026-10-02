# One email per hosted account that has not received an SES event two days
# after approval (signup, once accounts are auto-approved), with copy matched
# to where setup stopped. Runs from the `setup_nudge` entry in
# config/recurring.yml, guarded by Sessy.saas? so OSS installs never evaluate
# this constant.
#
# Eligibility is per account so a multi-source account gets one mail, and has
# no upper age bound so the first scheduled run reaches every account already
# stalled. Each account is claimed with a conditional UPDATE before anything
# is enqueued: Solid Queue lives in its own database, so claim and enqueue
# cannot share a transaction, and a deploy can kill the recurring command
# mid-loop. Losing an email to that window is acceptable; sending it twice
# is not.
module Sessy::Saas::SetupNudge
  GRACE_PERIOD = 2.days

  def self.eligible_accounts
    Account
      .where(instance: false, setup_nudge_sent_at: nil)
      .where(approved_at: ..GRACE_PERIOD.ago)
      .where.not(id: Source.where.not(first_event_at: nil).select(:account_id))
  end

  def self.deliver_due
    eligible_accounts.find_each { |account| deliver(account) }
  end

  # Claims the account, then enqueues one mail addressed to all its users.
  # Returns false when another run already claimed it.
  def self.deliver(account)
    return false unless claim(account)

    Sessy::Saas::SetupNudgeMailer.nudge(account).deliver_later
    true
  end

  def self.claim(account)
    Account.where(id: account.id, setup_nudge_sent_at: nil).update_all(setup_nudge_sent_at: Time.current) == 1
  end

  def self.variant_for(account)
    if account.sources.none?
      :no_source
    elsif account.sources.where.not(subscribed_at: nil).none?
      :no_subscription
    else
      :no_event
    end
  end
end
