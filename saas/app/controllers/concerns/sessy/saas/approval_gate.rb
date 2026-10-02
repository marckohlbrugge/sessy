# Included into ApplicationController via the engine's to_prepare, so a suspended
# account (approved_at nulled by the operator) sees only the paused page on every
# current and future hosted route (opt-out per controller, not opt-in). Reads
# approved_at live per request, so suspension takes effect on the next request.
module Sessy::Saas::ApprovalGate
  extend ActiveSupport::Concern

  included do
    before_action :require_approved_account
  end

  class_methods do
    def allow_pending_access(**options)
      skip_before_action :require_approved_account, **options
    end
  end

  private

  def require_approved_account
    if Current.account.present? && !Current.account.approved?
      redirect_to main_app.pending_path
    end
  end
end
