class Sessy::Saas::ApprovalMailer < Sessy::Saas::ApplicationMailer
  def approved(account)
    @account = account
    user = account.users.first
    mail to: user.email_address, subject: "You're in — welcome to Sessy"
  end
end
