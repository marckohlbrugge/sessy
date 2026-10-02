require "test_helper"

class Sessy::Saas::SignupsTest < ActionDispatch::IntegrationTest
  test "new signup is approved on the spot and lands on its Production source's Setup page" do
    sign_up_as "new@example.com"

    # On the completion form now (membership-less user).
    get new_signup_completion_path
    assert_response :success

    assert_difference -> { Account.where(instance: false).count }, 1 do
      # Block form: the sign-in code job enqueued above no longer deserializes
      # (its magic link was consumed), so only jobs from this block may be scanned.
      assert_enqueued_email_with Sessy::Saas::AdminMailer, :new_signup, args: ->(args) { args.first.name == "Casey's Sessy" } do
        assert_enqueued_email_with Sessy::Saas::ApprovalMailer, :welcome, args: ->(args) { args.first.name == "Casey's Sessy" } do
          post signup_completion_path, params: { name: "Casey" }
        end
      end
    end

    account = Account.where(instance: false).last
    assert account.approved?
    assert_equal "owner", account.memberships.first.role

    source = account.sources.sole
    assert_equal "Production", source.name
    assert_redirected_to source_setup_path(source)

    # The follow-up GET renders Setup, not the pending page.
    follow_redirect!
    assert_response :success
    assert_select "a, span", text: "Launch Stack"
  end

  test "a suspended account sees only the paused page and its webhook 404s" do
    user = sign_up_and_complete "suspended@example.com", "Dana"
    account = user.accounts.first
    source = account.sources.first

    get source_setup_path(source)
    assert_response :success

    account.update!(approved_at: nil)

    get source_setup_path(source)
    assert_redirected_to pending_path
    follow_redirect!
    assert_select "h1", text: "This account is paused"

    post webhook_path(source.token), params: { "Type" => "SubscriptionConfirmation", "SubscribeURL" => "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription" }, as: :json
    assert_response :not_found
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

    assert_no_difference [ -> { Account.where(instance: false).count }, -> { Membership.count }, -> { Source.count } ] do
      assert_no_enqueued_emails do
        post signup_completion_path, params: { name: "" }
      end
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
