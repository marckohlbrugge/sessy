require "test_helper"

class GlamaCardsControllerTest < ActionDispatch::IntegrationTest
  test "glama claim file is public when ADMIN_EMAIL is set" do
    with_admin_email("hey@example.com") do
      get "/.well-known/glama.json"

      assert_response :success
      card = JSON.parse(response.body)

      assert_equal "https://glama.ai/mcp/schemas/connector.json", card["$schema"]
      assert_equal [ { "email" => "hey@example.com" } ], card["maintainers"]
    end
  end

  test "glama claim file is not found without ADMIN_EMAIL" do
    with_admin_email(nil) do
      get "/.well-known/glama.json"

      assert_response :not_found
    end
  end

  test "a configured API host serves the claim file without redirecting" do
    original_api = Rails.configuration.x.api_host
    original_app = Rails.configuration.x.app_host
    Rails.configuration.x.api_host = "api.sessy.test"
    Rails.configuration.x.app_host = "app.sessy.test"

    with_admin_email("hey@example.com") do
      host! "api.sessy.test"
      get "/.well-known/glama.json"

      assert_response :success
      assert_equal "hey@example.com", JSON.parse(response.body).dig("maintainers", 0, "email")
    end
  ensure
    Rails.configuration.x.api_host = original_api
    Rails.configuration.x.app_host = original_app
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
