require "test_helper"

class Sessy::Saas::EditionHeadersTest < ActionDispatch::IntegrationTest
  test "responses carry the hosted edition header" do
    get root_path
    assert_response :success
    assert_equal "hosted", response.headers["X-Sessy-Edition"]
  end

  test "concern is wired via to_prepare" do
    assert ApplicationController.include?(Sessy::Saas::EditionHeaders)
  end

  test "auth challenges carry the edition header" do
    ENV["HTTP_AUTH_USERNAME"] = "user"
    ENV["HTTP_AUTH_PASSWORD"] = "secret"
    get root_path
    assert_response :unauthorized
    assert_equal "hosted", response.headers["X-Sessy-Edition"]
  ensure
    ENV.delete("HTTP_AUTH_USERNAME")
    ENV.delete("HTTP_AUTH_PASSWORD")
  end
end
