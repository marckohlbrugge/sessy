# Engine mailers send from the hosted address. Set here rather than via
# ActionMailer::Base.default, which the core ApplicationMailer's own
# `default from:` would otherwise shadow.
class Sessy::Saas::ApplicationMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "Sessy <hello@sessy.do>")
end
