# The one-time setup nudge (Sessy::Saas::SetupNudge). Addressed to every user
# of the account; when there is nobody to write to, the action returns
# without calling `mail`, yielding a NullMail that Action Mailer discards.
class Sessy::Saas::SetupNudgeMailer < Sessy::Saas::ApplicationMailer
  def nudge(account)
    recipients = account.users.pluck(:email_address)
    return if recipients.empty?

    @account = account
    @variant = Sessy::Saas::SetupNudge.variant_for(account)
    @source = next_step_source(account)
    @next_step_url = @source ? source_setup_url(@source) : new_source_url

    mail to: recipients, reply_to: ENV["ADMIN_EMAIL"].presence, subject: "Need a hand connecting SES to Sessy?"
  end

  private

  # The source the email talks about: the one SNS is connected to when there
  # is one (the :no_event copy describes it as connected), else the oldest.
  def next_step_source(account)
    sources = account.sources.order(:created_at, :id)
    sources.where.not(subscribed_at: nil).first || sources.first
  end
end
