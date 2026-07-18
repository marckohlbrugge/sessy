class Sessy::Saas::SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  # Per-IP throttle, plus a per-target-email throttle so the endpoint can't be
  # used to spam one victim's inbox (or burn SES reputation) from rotating IPs.
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded
  rate_limit to: 5, within: 3.minutes, only: :create, by: -> { params[:email_address].to_s.strip.downcase }, with: :rate_limit_exceeded

  layout "sessy/saas/public"

  def new
  end

  def create
    user = User.find_or_create_by!(email_address: email_address)
    purpose = user.memberships.none? ? :sign_up : :sign_in
    magic_link = user.mint_magic_link(purpose: purpose)

    Sessy::Saas::CodeMailer.sign_in_code(magic_link).deliver_later
    set_pending_authentication_token(magic_link)
    serve_development_code(magic_link)

    redirect_to session_code_path
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private

  def email_address
    params.expect(:email_address).to_s.strip.downcase
  end

  def rate_limit_exceeded
    redirect_to new_session_path, alert: "Too many attempts. Try again later."
  end
end
