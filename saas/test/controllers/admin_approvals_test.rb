require "test_helper"

class Sessy::Saas::AdminApprovalsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(name: "Casey's Sessy", retention_days: 30)
    @account.memberships.create!(user: User.create!(email_address: "casey@example.com"), role: "owner")
    @token = @account.signed_id(purpose: :admin_approval, expires_in: 30.days)
  end

  test "approval page shows the pending account without signing in" do
    get admin_approval_path(token: @token)

    assert_response :success
    assert_select "h1", text: "Casey's Sessy"
    assert_select "form" # the approve button
  end

  test "approving from the emailed link approves the account and emails the user" do
    assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :approved, args: [ @account ] do
      post admin_approval_path(token: @token)
    end

    assert @account.reload.approved?
    follow_redirect!
    assert_select "form", count: 0 # button gone once approved
  end

  test "approving an already-approved account does not re-email the user" do
    @account.approve!

    assert_no_enqueued_emails do
      post admin_approval_path(token: @token)
    end
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
  end
end
