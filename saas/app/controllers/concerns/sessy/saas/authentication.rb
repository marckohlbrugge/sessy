# Included into ApplicationController via the engine's to_prepare (after the
# core Authentication and SetCurrentAccount concerns), so its `authenticate` and
# `set_current_account` shadow the OSS versions in hosted mode. The session
# scheme fully replaces HTTP Basic — the old shared credential is inert here.
module Sessy::Saas::Authentication
  extend ActiveSupport::Concern

  include Sessy::Saas::Authentication::ViaMagicCode

  included do
    before_action :require_signup_completion
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :authenticate, **options
      skip_before_action :set_current_account, **options
    end

    # For the completion form itself, which a membership-less user must reach.
    def allow_incomplete_signup(**options)
      skip_before_action :require_signup_completion, **options
    end
  end

  private

  def authenticate
    resume_session || request_authentication
  end

  def resume_session
    if session_record = find_session_by_cookie
      if session_record.expired?
        session_record.destroy
        cookies.delete(:session_token)
        nil
      else
        session_record.touch_if_stale
        set_current_session(session_record)
        true
      end
    end
  end

  def find_session_by_cookie
    Session.find_signed(cookies.signed[:session_token]) if cookies.signed[:session_token]
  end

  def set_current_session(session_record)
    Current.session = session_record
    Current.user = session_record.user
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url if request.get? || request.head?
    # main_app. so the helper resolves against the app's routes even when the
    # request is inside a mounted engine (e.g. Mission Control at /jobs).
    redirect_to main_app.new_session_path
  end

  # A signed-in user with no membership (mid-signup or abandoned completion)
  # must finish signup before reaching any tenant surface.
  def require_signup_completion
    if Current.user.present? && Current.account.nil?
      redirect_to main_app.new_signup_completion_path
    end
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session_record|
      set_current_session(session_record)
      cookies.signed.permanent[:session_token] = {
        value: session_record.signed_id,
        httponly: true,
        secure: !Rails.env.local?,
        same_site: :lax
      }
    end
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
  end

  # Hosted account resolution: the signed-in user's sole account (nil on the
  # pre-auth pages). Refined by U5's tenancy scoping.
  def set_current_account
    Current.account = Current.user&.accounts&.first
  end
end
