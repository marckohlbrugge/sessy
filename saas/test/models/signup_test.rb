require "test_helper"

class Sessy::Saas::SignupTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.create!(email_address: "casey@example.com")
  end

  test "complete creates an approved account with one Production source and emails both sides" do
    signup = Sessy::Saas::Signup.new(user: @user, name: "Casey")

    account = nil
    assert_enqueued_emails 2 do
      account = signup.complete
    end

    assert account.approved?
    assert_equal "Casey's Sessy", account.name
    assert_equal Sessy::Saas::Signup::HOSTED_RETENTION_DAYS, account.retention_days
    assert_equal "owner", account.memberships.find_by(user: @user).role

    assert_equal [ "Production" ], account.sources.pluck(:name)
    assert_includes Source::Colors::ALL, account.sources.first.color

    assert_enqueued_email_with Sessy::Saas::AdminMailer, :new_signup, args: [ account ]
    assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :welcome, args: [ account ]
  end

  test "complete with an invalid name creates nothing and enqueues nothing" do
    signup = Sessy::Saas::Signup.new(user: @user, name: "")

    assert_no_difference [ -> { Account.count }, -> { Membership.count }, -> { Source.count } ] do
      assert_no_enqueued_emails do
        assert_not signup.complete
      end
    end
  end
end
