require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
  end

  test "index lists only the current account's keys, showing prefixes not tokens" do
    other_account = Account.create!(name: "Other", approved_at: Time.current)
    other_account.api_keys.create!(name: "Other agent")

    get api_keys_path

    assert_response :success
    assert_match "Test agent", response.body
    assert_no_match "Other agent", response.body
    assert_match api_keys(:instance_key).token_prefix, response.body
    assert_no_match "sessy_instance_test_key", response.body
  end

  test "create shows the token once and never again" do
    assert_difference "ApiKey.count", 1 do
      post api_keys_path, params: { api_key: { name: "Claude Code" } }
    end

    assert_redirected_to api_keys_path
    follow_redirect!
    token = ApiKey.order(:created_at).last
    assert_match(/sessy_\w+/, response.body)

    get api_keys_path
    assert_no_match(/sessy_\w{20,}/, response.body)
    assert_equal accounts(:instance), token.account
  end

  test "create with a blank name re-renders with errors" do
    assert_no_difference "ApiKey.count" do
      post api_keys_path, params: { api_key: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "destroy revokes the key" do
    delete api_key_path(api_keys(:instance_key))

    assert_redirected_to api_keys_path
    assert_nil ApiKey.find_by_token("sessy_instance_test_key")
  end

  test "cannot revoke another account's key" do
    other_account = Account.create!(name: "Other", approved_at: Time.current)
    other_key = other_account.api_keys.create!(name: "Other agent")

    delete api_key_path(other_key)

    assert_response :not_found
    assert other_key.reload.persisted?
  end
end
