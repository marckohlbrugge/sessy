# The welcome email: sent at signup (Signup#complete) and again when a
# suspended account is restored (AccountApproval#approve!). It deep-links to
# the first source's Setup page, which the sign-in flow resumes after the
# magic code. Accounts from before sources were auto-created have none, so
# they get the sign-in page instead.
class Sessy::Saas::ApprovalMailer < Sessy::Saas::ApplicationMailer
  def welcome(account)
    @account = account
    @source = account.sources.first

    mail to: account.users.first.email_address, subject: "Welcome to Sessy"
  end
end
