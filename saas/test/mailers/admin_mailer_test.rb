require "test_helper"

class Sessy::Saas::AdminMailerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
  end

  test "new signup email goes to ADMIN_EMAIL with a working approval link" do
    with_admin_email "admin@example.com" do
      mail = Sessy::Saas::AdminMailer.new_signup(@account)

      assert_equal [ "admin@example.com" ], mail.to
      assert_includes mail.subject, "Casey's Sessy"

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
