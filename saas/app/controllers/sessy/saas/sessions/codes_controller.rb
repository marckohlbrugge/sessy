class Sessy::Saas::Sessions::CodesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  before_action :ensure_pending_authentication

  layout "sessy/saas/public"

  def show
  end

  def create
    if magic_link = MagicLink.consume(params[:code])
      verify(magic_link)
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

  # The code alone isn't enough: it must match the browser that requested it.
  def verify(magic_link)
    if ActiveSupport::SecurityUtils.secure_compare(email_address_pending_authentication.to_s, magic_link.user.email_address)
      clear_pending_authentication_token
      start_new_session_for(magic_link.user)
      redirect_to after_sign_in_path(magic_link.user)
    else
      clear_pending_authentication_token
      redirect_to new_session_path, alert: "Something went wrong. Please try again."
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
