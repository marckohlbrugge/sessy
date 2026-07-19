require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "creating a key yields a sessy_-prefixed token and stores only its digest" do
    api_key = accounts(:instance).api_keys.create!(name: "Editor")

    assert api_key.token.start_with?("sessy_")
    assert_equal ApiKey.digest(api_key.token), api_key.token_digest
    assert_not api_key.attributes.values.include?(api_key.token)
    assert api_key.token_prefix.start_with?("sessy_")
    assert_operator api_key.token_prefix.length, :<, api_key.token.length
  end

  test "find_by_token resolves the raw token via its digest" do
    api_key = accounts(:instance).api_keys.create!(name: "Editor")

    assert_equal api_key, ApiKey.find_by_token(api_key.token)
    assert_nil ApiKey.find_by_token("sessy_wrong")
    assert_nil ApiKey.find_by_token(nil)
  end

  test "destroyed keys no longer resolve" do
    api_key = accounts(:instance).api_keys.create!(name: "Editor")
    token = api_key.token

    api_key.destroy
    assert_nil ApiKey.find_by_token(token)
  end

  test "destroying an account destroys its keys" do
    account = Account.create!(name: "Doomed", approved_at: Time.current)
    account.api_keys.create!(name: "Editor")

    assert_difference "ApiKey.count", -1 do
      account.destroy
    end
  end

  test "requires a name" do
    api_key = accounts(:instance).api_keys.new
    assert_not api_key.valid?
    assert api_key.errors[:name].any?
  end

  test "track_usage stamps last_used_at at most once per hour" do
    api_key = accounts(:instance).api_keys.create!(name: "Editor")

    freeze_time do
      api_key.track_usage
      assert_equal Time.current, api_key.reload.last_used_at

      travel 30.minutes
      api_key.track_usage
      assert_equal 30.minutes.ago, api_key.reload.last_used_at

      travel 31.minutes
      api_key.track_usage
      assert_equal Time.current, api_key.reload.last_used_at
    end
  end
end
