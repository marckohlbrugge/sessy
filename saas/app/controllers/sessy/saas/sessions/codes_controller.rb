class Sessy::Saas::Sessions::CodesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  before_action :ensure_pending_authentication

  layout "sessy/saas/public"

  def show
  end

  # The code must match the browser that requested it (pending-auth cookie), and
  # is only consumed on a successful match — a wrong-browser guess leaves the
  # real user's code intact.
  def create
    if magic_link = MagicLink.authenticate(params[:code], email: email_address_pending_authentication)
      clear_pending_authentication_token
      start_new_session_for(magic_link.user)
      redirect_to after_sign_in_path(magic_link.user)
    else
      redirect_to session_code_path, alert: "That code didn't work. Try again."
    end
  end

  private

  def ensure_pending_authentication
    unless email_address_pending_authentication.present?
      redirect_to new_session_path, alert: "Enter your email address to sign in."
    end
  end

  # Route by membership presence, not code purpose: an abandoned signup leaves a
  # membership-less user whose next code is sign_in-purpose, but they still need
  # the completion form.
  def after_sign_in_path(user)
    if user.memberships.none?
      new_signup_completion_path
    else
      root_path
    end
  end

  def rate_limit_exceeded
    redirect_to session_code_path, alert: "Too many attempts. Try again in 15 minutes."
  end
end
