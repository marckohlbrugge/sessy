# The one page a suspended account (approved_at nulled by the operator) can
# see. Named for the original pending-approval flow; accounts are approved at
# signup now, so a nil approved_at means "paused", not "waiting".
class Sessy::Saas::PendingsController < ApplicationController
  # Skip the gate here or paused users would redirect-loop.
  allow_pending_access

  layout "sessy/saas/public"

  def show
    redirect_to root_path if Current.account.nil? || Current.account.approved?
    @support_address = Mail::Address.new(Sessy::Saas::ApplicationMailer.default[:from]).address
  end
end
