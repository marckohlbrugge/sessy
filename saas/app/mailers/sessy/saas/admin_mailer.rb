# Operator notifications, sent to ADMIN_EMAIL. When that env var is unset the
# actions return without calling `mail`, which yields a NullMail that Action
# Mailer quietly discards — no recipient, no delivery, no error.
class Sessy::Saas::AdminMailer < Sessy::Saas::ApplicationMailer
  ACCOUNT_LINK_VALIDITY = 30.days

  # FYI only: accounts are approved at signup. The link opens the admin account
  # page, where the operator can suspend (and later restore) the account.
  def new_signup(account)
    return if admin_address.blank?

    @account = account
    @user = account.users.first
    @account_url = admin_approval_url(token: account.signed_id(purpose: :admin_approval, expires_in: ACCOUNT_LINK_VALIDITY))
    mail to: admin_address, subject: "New Sessy signup (auto-approved): #{account.name}"
  end

  private

  def admin_address
    ENV["ADMIN_EMAIL"]
  end
end
