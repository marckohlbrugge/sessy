# Prepended onto Account via the engine's to_prepare. Core Account#approve!
# only sets the timestamp; the engine layers the notification email on top, so
# the OSS bundle never references a mailer.
module Sessy::Saas::AccountApproval
  def approve!
    was_approved = approved?
    super
    Sessy::Saas::ApprovalMailer.approved(self).deliver_later unless was_approved
  end
end
