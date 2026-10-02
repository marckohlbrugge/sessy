# Prepended onto Account via the engine's to_prepare. Core Account#approve!
# only sets the timestamp; the engine layers the welcome email on top, so the
# OSS bundle never references a mailer. Signup approves inline instead (the
# email must wait for its transaction to commit), so this fires when a
# suspended account is restored.
module Sessy::Saas::AccountApproval
  def approve!
    was_approved = approved?
    super
    Sessy::Saas::ApprovalMailer.welcome(self).deliver_later unless was_approved
  end
end
