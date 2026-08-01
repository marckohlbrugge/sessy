require "test_helper"

class McpServerCardsControllerTest < ActionDispatch::IntegrationTest
  test "server card is public and lists the MCP tools" do
    get "/.well-known/mcp/server-card.json"

    assert_response :success
    card = JSON.parse(response.body)

    assert_equal "sessy", card.dig("serverInfo", "name")
    assert_equal McpServer::VERSION, card.dig("serverInfo", "version")
    assert_equal true, card.dig("authentication", "required")
    assert_equal [ "bearer" ], card.dig("authentication", "schemes")
    assert_equal %w[list_sources search_events get_message email_stats],
      card["tools"].map { |tool| tool["name"] }
    assert_not_includes card.dig("authentication", "schemes"), "oauth2"
  end

  test "a configured API host serves the server card without redirecting" do
    original_api = Rails.configuration.x.api_host
    original_app = Rails.configuration.x.app_host
    Rails.configuration.x.api_host = "api.sessy.test"
    Rails.configuration.x.app_host = "app.sessy.test"

    host! "api.sessy.test"
    get "/.well-known/mcp/server-card.json"

    assert_response :success
    assert_equal "sessy", JSON.parse(response.body).dig("serverInfo", "name")
  ensure
    Rails.configuration.x.api_host = original_api
    Rails.configuration.x.app_host = original_app
  end
end
