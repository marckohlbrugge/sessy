# The one-time setup nudge (Sessy::Saas::SetupNudge). Addressed to every user
# of the account; when there is nobody to write to, the action returns
# without calling `mail`, yielding a NullMail that Action Mailer discards.
class Sessy::Saas::SetupNudgeMailer < Sessy::Saas::ApplicationMailer
  def nudge(account)
    recipients = account.users.pluck(:email_address)
    return if recipients.empty?

    @account = account
    @variant = Sessy::Saas::SetupNudge.variant_for(account)
    @source = account.sources.order(:created_at, :id).first
    @next_step_url = @source ? source_setup_url(@source) : new_source_url

    headers = { to: recipients, subject: "Need a hand connecting SES to Sessy?" }
    headers[:reply_to] = ENV["ADMIN_EMAIL"] if ENV["ADMIN_EMAIL"].present?
    mail headers
  end
end
