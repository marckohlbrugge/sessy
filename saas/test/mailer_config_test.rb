require "test_helper"

class Sessy::Saas::MailerConfigTest < ActiveSupport::TestCase
  test "hosted from-address and url host are configured" do
    assert_equal [ ENV.fetch("MAILER_FROM_ADDRESS", "Sessy <hello@sessy.do>") ], Array(ActionMailer::Base.default[:from])
    assert_equal "app.sessy.do", ActionMailer::Base.default_url_options[:host]
  end

  test "code mailer addresses the user with the code in the subject" do
    user = User.create!(email_address: "mailer@example.com")
    link = user.mint_magic_link
    mail = Sessy::Saas::CodeMailer.sign_in_code(link)
    assert_equal [ "mailer@example.com" ], mail.to
    assert_match link.code, mail.subject
  end
end
