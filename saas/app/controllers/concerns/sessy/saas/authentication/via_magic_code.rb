# The pending-authentication cookie binds a code to the browser that requested
# it, and the development-mode code display (with a leak guard). Adapted from
# Fizzy's Authentication::ViaMagicLink.
module Sessy::Saas::Authentication::ViaMagicCode
  extend ActiveSupport::Concern

  included do
    after_action :ensure_development_code_not_leaked
  end

  private

  def set_pending_authentication_token(magic_link)
    cookies[:pending_authentication_token] = {
      value: pending_authentication_token_verifier.generate(magic_link.user.email_address, expires_at: magic_link.expires_at),
      httponly: true,
      secure: !Rails.env.local?,
      same_site: :lax,
      expires: magic_link.expires_at
    }
  end

  def email_address_pending_authentication
    pending_authentication_token_verifier.verified(cookies[:pending_authentication_token])
  end

  def clear_pending_authentication_token
    cookies.delete(:pending_authentication_token)
  end

  def pending_authentication_token_verifier
    Rails.application.message_verifier(:pending_authentication)
  end

  # Development convenience: surface the code so no mail setup is needed locally.
  # Gated strictly on Rails.env.development? (never SESSY_MODE), with a guard
  # that fails loud if it ever leaks in another environment.
  def serve_development_code(magic_link)
    if Rails.env.development?
      flash[:magic_code] = magic_link.code
      response.set_header("X-Magic-Code", magic_link.code)
    end
  end

  def ensure_development_code_not_leaked
    unless Rails.env.development?
      raise "Leaking magic code via flash in #{Rails.env}?" if flash[:magic_code].present?
    end
  end
end
