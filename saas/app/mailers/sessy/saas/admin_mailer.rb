# Operator notifications, sent to ADMIN_EMAIL. When that env var is unset the
# actions return without calling `mail`, which yields a NullMail that Action
# Mailer quietly discards — no recipient, no delivery, no error.
class Sessy::Saas::AdminMailer < Sessy::Saas::ApplicationMailer
  APPROVAL_LINK_VALIDITY = 30.days

  def new_signup(account)
    return if admin_address.blank?

    @account = account
    @user = account.users.first
    @approval_url = admin_approval_url(token: account.signed_id(purpose: :admin_approval, expires_in: APPROVAL_LINK_VALIDITY))
    mail to: admin_address, subject: "New Sessy signup: #{account.name}"
  end

  private

  def admin_address
    ENV["ADMIN_EMAIL"]
  end
end
