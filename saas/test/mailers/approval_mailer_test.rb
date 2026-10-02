require "test_helper"

class Sessy::Saas::ApprovalMailerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: Time.current)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
  end

  test "welcome email links to the first source's Setup page and describes Launch Stack" do
    source = @account.sources.create!(name: "Production")
    mail = Sessy::Saas::ApprovalMailer.welcome(@account)

    assert_equal [ "casey@example.com" ], mail.to
    assert_equal "Welcome to Sessy", mail.subject

    setup_url = Rails.application.routes.url_helpers.source_setup_url(source, **ActionMailer::Base.default_url_options)
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, setup_url
      assert_includes body, "Launch Stack"
      assert_no_match(/approved/i, body)
    end
  end

  test "welcome email for an account without sources falls back to the sign-in page" do
    mail = Sessy::Saas::ApprovalMailer.welcome(@account)

    sign_in_url = Rails.application.routes.url_helpers.new_session_url(**ActionMailer::Base.default_url_options)
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, sign_in_url
      assert_no_match(%r{/sources/\d+/setup}, body)
    end
  end

  test "approve! on a suspended account re-sends the welcome email" do
    @account.update!(approved_at: nil)

    assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :welcome, args: [ @account ] do
      @account.approve!
    end
  end

  test "approve! on an already-approved account sends nothing" do
    assert_no_enqueued_emails do
      @account.approve!
    end
  end
end
