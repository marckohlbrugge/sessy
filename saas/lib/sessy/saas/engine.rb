module Sessy
  module Saas
    class Engine < ::Rails::Engine
      initializer "sessy_saas.routes" do |app|
        app.routes.append do
          resource :saas_info, only: :show, controller: "sessy/saas/infos", path: "saas/info"

          resource :session, only: [ :new, :create, :destroy ], controller: "sessy/saas/sessions"
          resource :session_code, only: [ :show, :create ], controller: "sessy/saas/sessions/codes", path: "session/code"
          resource :signup_completion, only: [ :new, :create ], controller: "sessy/saas/signups/completions", path: "signup/complete"
          resource :pending, only: :show, controller: "sessy/saas/pendings"
        end
      end

      initializer "sessy_saas.action_mailer", after: "action_mailer.set_configs" do
        ActionMailer::Base.default from: ENV.fetch("MAILER_FROM_ADDRESS", "Sessy <hello@sessy.do>")
        ActionMailer::Base.default_url_options = {
          host: ENV.fetch("APP_HOST", "app.sessy.do"),
          protocol: "https"
        }
        # SES sending credentials arrive via Kamal secrets / host IAM role; the
        # :ses_v2 client is created lazily on first send, so boot needs no creds.
        ActionMailer::Base.delivery_method = :ses_v2 if Rails.env.production?
      end

      config.to_prepare do
        ApplicationController.include Sessy::Saas::EditionHeaders
        ApplicationController.include Sessy::Saas::Authentication
        ApplicationController.include Sessy::Saas::ApprovalGate
        Account.prepend Sessy::Saas::AccountApproval
      end
    end
  end
end
