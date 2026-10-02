class Sessy::Saas::Signups::CompletionsController < ApplicationController
  allow_incomplete_signup
  before_action :require_membership_absent

  layout "sessy/saas/public"

  def new
    @signup = Sessy::Saas::Signup.new(user: Current.user)
  end

  def create
    @signup = Sessy::Saas::Signup.new(user: Current.user, name: params[:name])

    if account = @signup.complete
      # Straight onto the first source's Setup page while attention is high.
      redirect_to source_setup_path(account.sources.first)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Already has an account? Nothing to complete.
  def require_membership_absent
    redirect_to root_path if Current.user&.memberships&.any?
  end
end
