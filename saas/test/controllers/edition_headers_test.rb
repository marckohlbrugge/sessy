require "test_helper"

class Sessy::Saas::EditionHeadersTest < ActionDispatch::IntegrationTest
  test "responses carry the hosted edition header" do
    get saas_info_path
    assert_response :success
    assert_equal "hosted", response.headers["X-Sessy-Edition"]
  end

  test "concern is wired via to_prepare" do
    assert ApplicationController.include?(Sessy::Saas::EditionHeaders)
  end

  test "the header is stamped before auth halts the chain" do
    # Unauthenticated tenant request redirects to sign-in but still carries the
    # edition marker (set via prepend_before_action, ahead of authenticate).
    get root_path
    assert_redirected_to new_session_path
    assert_equal "hosted", response.headers["X-Sessy-Edition"]
  end
end
