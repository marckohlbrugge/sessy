class Sessy::Saas::PendingsController < ApplicationController
  # Skip the gate here or pending users would redirect-loop.
  allow_pending_access

  layout "sessy/saas/public"

  def show
    redirect_to root_path if Current.account.nil? || Current.account.approved?
  end
end
