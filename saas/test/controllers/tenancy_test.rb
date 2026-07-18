require "test_helper"

class Sessy::Saas::TenancyTest < ActionDispatch::IntegrationTest
  test "a user cannot reach another account's source" do
    _account_a, user_a, source_a = approved_account("a@example.com")
    _account_b, _user_b, source_b = approved_account("b@example.com")

    sign_in user_a

    get source_path(source_a)
    assert_response :success

    # Another account's source is invisible (404, not 403 — no existence leak).
    get source_path(source_b)
    assert_response :not_found
  end

  test "index shows only the current account's sources" do
    _account_a, user_a, source_a = approved_account("a2@example.com")
    _account_b, _user_b, source_b = approved_account("b2@example.com")

    sign_in user_a
    get sources_path
    assert_select "a[href=?]", source_path(source_a)
    assert_select "a[href=?]", source_path(source_b), count: 0
  end

  test "webhook ingests for an approved account's source" do
    account = Account.create!(name: "Approved", approved_at: Time.current)
    source = account.sources.create!(name: "Src")

    post webhook_path(source.token), params: subscription_confirmation, as: :json
    assert_response :success
  end

  test "webhook is refused once the account is un-approved" do
    account = Account.create!(name: "Revoked", approved_at: Time.current)
    source = account.sources.create!(name: "Src")
    account.update!(approved_at: nil)

    post webhook_path(source.token), params: subscription_confirmation, as: :json
    assert_response :not_found
  end

  private

  def approved_account(email)
    account = Account.create!(name: "#{email} co", approved_at: Time.current)
    user = User.create!(email_address: email)
    account.memberships.create!(user: user)
    source = account.sources.create!(name: "Src")
    [ account, user, source ]
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address }
    post session_code_path, params: { code: MagicLink.last.code }
  end

  def subscription_confirmation
    { "Type" => "SubscriptionConfirmation", "SubscribeURL" => "https://example.com/confirm" }
  end
end
