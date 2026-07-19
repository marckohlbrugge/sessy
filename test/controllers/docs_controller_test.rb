require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
  end

  test "docs show the request host in the endpoint URL when API_HOST is unset" do
    get mcp_docs_path

    assert_response :success
    assert_match "http://www.example.com/mcp", response.body
    assert_match "list_sources", response.body
    assert_match "Cloudflare", response.body
  end

  test "docs show the configured api host when API_HOST is set" do
    original = Rails.configuration.x.api_host
    Rails.configuration.x.api_host = "api.sessy.test"

    get mcp_docs_path

    assert_response :success
    assert_match "https://api.sessy.test/mcp", response.body
  ensure
    Rails.configuration.x.api_host = original
  end
end
