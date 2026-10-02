require "test_helper"

class Sessy::Saas::SetupNudgeMailerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: 3.days.ago)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
  end

  test "no-source variant goes to every user and points at source creation" do
    @account.memberships.create!(user: User.create!(email_address: "jordan@example.com"), role: "member")

    mail = Sessy::Saas::SetupNudgeMailer.nudge(@account)

    assert_equal [ "casey@example.com", "jordan@example.com" ], mail.to.sort
    assert_equal [ "hello@sessy.do" ], mail.from
    assert_includes mail.subject, "Sessy"
    each_body(mail) do |body|
      assert_includes body, new_source_url
      assert_match(/create .*source/i, body)
      assert_includes body, "reply"
    end
  end

  test "no-subscription variant links to the oldest source's Setup page and names Launch Stack" do
    newer = @account.sources.create!(name: "Staging")
    oldest = @account.sources.create!(name: "Production", created_at: 2.days.ago)

    mail = Sessy::Saas::SetupNudgeMailer.nudge(@account)

    each_body(mail) do |body|
      assert_includes body, source_setup_url(oldest)
      assert_not_includes body, source_setup_url(newer)
      assert_includes body, "Launch Stack"
      assert_includes body, "Production"
    end
  end

  test "no-event variant names the configuration set and the SES sandbox" do
    source = @account.sources.create!(name: "Production", subscribed_at: 1.day.ago)

    mail = Sessy::Saas::SetupNudgeMailer.nudge(@account)

    each_body(mail) do |body|
      assert_includes body, source_setup_url(source)
      assert_includes body, source.config_set_name
      assert_includes body, "sandbox"
      assert_not_includes body, "Launch Stack"
    end
  end

  test "replies go to the operator when ADMIN_EMAIL is set, otherwise to the sender" do
    with_admin_email "admin@example.com" do
      assert_equal [ "admin@example.com" ], Sessy::Saas::SetupNudgeMailer.nudge(@account).reply_to
    end

    with_admin_email nil do
      assert_nil Sessy::Saas::SetupNudgeMailer.nudge(@account).reply_to
    end
  end

  test "an account without users sends nothing" do
    @account.memberships.destroy_all

    assert_no_emails do
      Sessy::Saas::SetupNudgeMailer.nudge(@account).deliver_now
    end
  end

  private

  def each_body(mail)
    assert_equal 2, mail.parts.size, "expected text and html parts"
    [ mail.text_part, mail.html_part ].each do |part|
      yield part.body.to_s
    end
  end

  def with_admin_email(address)
    original = ENV["ADMIN_EMAIL"]
    address.nil? ? ENV.delete("ADMIN_EMAIL") : ENV["ADMIN_EMAIL"] = address
    yield
  ensure
    original.nil? ? ENV.delete("ADMIN_EMAIL") : ENV["ADMIN_EMAIL"] = original
  end

  def new_source_url
    Rails.application.routes.url_helpers.new_source_url(ActionMailer::Base.default_url_options)
  end

  def source_setup_url(source)
    Rails.application.routes.url_helpers.source_setup_url(source, ActionMailer::Base.default_url_options)
  end
end
