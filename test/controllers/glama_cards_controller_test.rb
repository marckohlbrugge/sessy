require "test_helper"

class GlamaCardsControllerTest < ActionDispatch::IntegrationTest
  test "glama claim file is public when GLAMA_MAINTAINER_EMAIL is set" do
    with_glama_maintainer_email("subscriptions@example.com") do
      get "/.well-known/glama.json"

      assert_response :success
      card = JSON.parse(response.body)

      assert_equal "https://glama.ai/mcp/schemas/connector.json", card["$schema"]
      assert_equal [ { "email" => "subscriptions@example.com" } ], card["maintainers"]
    end
  end

  test "glama claim file is not found without GLAMA_MAINTAINER_EMAIL" do
    with_glama_maintainer_email(nil) do
      get "/.well-known/glama.json"

      assert_response :not_found
    end
  end

  test "a configured API host serves the claim file without redirecting" do
    original_api = Rails.configuration.x.api_host
    original_app = Rails.configuration.x.app_host
    Rails.configuration.x.api_host = "api.sessy.test"
    Rails.configuration.x.app_host = "app.sessy.test"

    with_glama_maintainer_email("subscriptions@example.com") do
      host! "api.sessy.test"
      get "/.well-known/glama.json"

      assert_response :success
      assert_equal "subscriptions@example.com", JSON.parse(response.body).dig("maintainers", 0, "email")
    end
  ensure
    Rails.configuration.x.api_host = original_api
    Rails.configuration.x.app_host = original_app
  end

  private
    def with_glama_maintainer_email(address)
      original = ENV["GLAMA_MAINTAINER_EMAIL"]
      address.nil? ? ENV.delete("GLAMA_MAINTAINER_EMAIL") : ENV["GLAMA_MAINTAINER_EMAIL"] = address
      yield
    ensure
      original.nil? ? ENV.delete("GLAMA_MAINTAINER_EMAIL") : ENV["GLAMA_MAINTAINER_EMAIL"] = original
    end
end
