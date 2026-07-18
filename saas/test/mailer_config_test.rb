require "test_helper"

class Sessy::Saas::MailerConfigTest < ActiveSupport::TestCase
  test "hosted url host is configured" do
    assert_equal "app.sessy.do", ActionMailer::Base.default_url_options[:host]
  end

  test "engine mail is sent from the hosted address, not the core default" do
    user = User.create!(email_address: "mailer@example.com")
    mail = Sessy::Saas::CodeMailer.sign_in_code(user.mint_magic_link)
    assert_equal [ "mailer@example.com" ], mail.to
    assert_equal [ "hello@sessy.do" ], mail.from
    assert_not_includes Array(mail.from), "from@example.com"
  end
end
