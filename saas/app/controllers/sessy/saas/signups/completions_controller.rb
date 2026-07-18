class Sessy::Saas::Signups::CompletionsController < ApplicationController
  allow_incomplete_signup
  before_action :require_membership_absent

  layout "sessy/saas/public"

  def new
    @signup = Sessy::Saas::Signup.new(user: Current.user)
  end

  def create
    @signup = Sessy::Saas::Signup.new(user: Current.user, name: params[:name])

    if @signup.complete
      redirect_to root_path
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
