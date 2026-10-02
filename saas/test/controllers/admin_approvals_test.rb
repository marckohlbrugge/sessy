require "test_helper"

class Sessy::Saas::AdminApprovalsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30, approved_at: Time.current)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
    @account.sources.create!(name: "Production")
    @token = @account.signed_id(purpose: :admin_approval, expires_in: 30.days)
  end

  test "account page shows an active account with a suspend button, without signing in" do
    get admin_approval_path(token: @token)

    assert_response :success
    assert_select "h1", text: "Casey's Sessy"
    assert_select "form button", text: "Suspend account"
  end

  test "suspending from the emailed link gates the account and its webhook" do
    source = @account.sources.first

    assert_no_enqueued_emails do
      delete admin_approval_path(token: @token)
    end

    assert_not @account.reload.approved?
    follow_redirect!
    assert_select "form button", text: "Restore account"

    stub_sns_confirmation # a gate regression must fail the assertion, not reach the network
    post webhook_path(source.token), params: { "Type" => "SubscriptionConfirmation", "SubscribeURL" => "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription" }, as: :json
    assert_response :not_found
  end

  test "restoring a suspended account approves it again and re-sends the welcome email" do
    @account.update!(approved_at: nil)

    assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :welcome, args: [ @account ] do
      post admin_approval_path(token: @token)
    end

    assert @account.reload.approved?
    follow_redirect!
    assert_select "form button", text: "Suspend account"
  end

  test "restoring an already-active account does not re-email the user" do
    assert_no_enqueued_emails do
      post admin_approval_path(token: @token)
    end
    assert @account.reload.approved?
    assert_equal "Account is already active.", flash[:notice]
  end

  test "garbage and expired tokens 404" do
    get admin_approval_path(token: "garbage")
    assert_response :not_found

    travel 31.days do
      get admin_approval_path(token: @token)
      assert_response :not_found
    end
  end

  test "tokens signed for other purposes are rejected" do
    get admin_approval_path(token: @account.signed_id(purpose: :something_else))
    assert_response :not_found

    delete admin_approval_path(token: @account.signed_id(purpose: :something_else))
    assert_response :not_found
    assert @account.reload.approved?
  end
end
