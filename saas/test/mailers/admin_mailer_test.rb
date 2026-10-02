require "test_helper"

class Sessy::Saas::AdminMailerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: Time.current)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
  end

  test "new signup FYI goes to ADMIN_EMAIL with a working link to the admin account page" do
    with_admin_email "admin@example.com" do
      mail = Sessy::Saas::AdminMailer.new_signup(@account)

      assert_equal [ "admin@example.com" ], mail.to
      assert_equal "New Sessy signup (auto-approved): Casey's Sessy", mail.subject

      [ mail.html_part, mail.text_part ].each do |part|
        body = part.body.to_s
        assert_includes body, "casey@example.com"
        assert_no_match(/pending until you approve/i, body)
        assert_match(/suspend/i, body)
      end

      token = mail.text_part.body.to_s[/token=([^\s&]+)/, 1]
      assert_equal @account, Account.find_signed(CGI.unescape(token), purpose: :admin_approval)
    end
  end

  test "no ADMIN_EMAIL means nothing is sent" do
    with_admin_email nil do
      assert_no_emails do
        Sessy::Saas::AdminMailer.new_signup(@account).deliver_now
      end
    end
  end

  private

  def with_admin_email(address)
    original = ENV["ADMIN_EMAIL"]
    address.nil? ? ENV.delete("ADMIN_EMAIL") : ENV["ADMIN_EMAIL"] = address
    yield
  ensure
    original.nil? ? ENV.delete("ADMIN_EMAIL") : ENV["ADMIN_EMAIL"] = original
  end
end
