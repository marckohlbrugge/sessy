require "test_helper"

class Sessy::Saas::SignupsTest < ActionDispatch::IntegrationTest
  test "new signup completes into a pending account and is gated" do
    sign_up_as "new@example.com"

    # On the completion form now (membership-less user).
    get new_signup_completion_path
    assert_response :success

    assert_difference -> { Account.where(instance: false).count }, 1 do
      post signup_completion_path, params: { name: "Casey" }
    end

    account = Account.where(instance: false).last
    assert_not account.approved?
    assert_equal "owner", account.memberships.first.role

    # Every tenant route now shows the pending page.
    get root_path
    assert_redirected_to pending_path
    get new_source_path
    assert_redirected_to pending_path
  end

  test "approval flips access on the next request and emails the user" do
    user = sign_up_and_complete "approve@example.com", "Dana"
    account = user.accounts.first

    get root_path
    assert_redirected_to pending_path

    assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :approved, args: [ account ] do
      account.approve!
    end

    get root_path
    assert_response :success
  end

  test "a signed-in membership-less user is sent to complete signup, not 500" do
    sign_up_as "midway@example.com"

    get root_path
    assert_redirected_to new_signup_completion_path

    get new_source_path
    assert_redirected_to new_signup_completion_path
  end

  test "signup transaction rolls back on failure leaving no orphans" do
    sign_up_as "blank@example.com"

    assert_no_difference [ -> { Account.where(instance: false).count }, -> { Membership.count } ] do
      post signup_completion_path, params: { name: "" }
    end
    assert_response :unprocessable_entity
  end

  private

  def sign_up_as(email)
    post session_path, params: { email_address: email }
    post session_code_path, params: { code: MagicLink.last.code }
    assert_redirected_to new_signup_completion_path
  end

  def sign_up_and_complete(email, name)
    sign_up_as email
    post signup_completion_path, params: { name: name }
    User.find_by(email_address: email)
  end
end
