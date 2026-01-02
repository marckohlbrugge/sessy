require "test_helper"

class Event::SearchableTest < ActiveSupport::TestCase
  # Search by recipient email

  test "search finds events by recipient email" do
    assert_includes Event.search("marc@example"), events(:welcome_send)
  end

  test "search finds events by partial email match" do
    assert_includes Event.search("john"), events(:digest_send)
    assert_includes Event.search("example.com"), events(:digest_send)
  end

  # Search by message subject

  test "search finds events by message subject" do
    assert_includes Event.search("Welcome"), events(:welcome_send)
  end

  test "search finds events by partial subject match" do
    assert_includes Event.search("Digest"), events(:digest_send)
  end

  # Case insensitivity

  test "search is case insensitive for recipient email" do
    assert_includes Event.search("MARC@EXAMPLE"), events(:welcome_send)
    assert_includes Event.search("Marc@Example"), events(:welcome_send)
  end

  test "search is case insensitive for subject" do
    assert_includes Event.search("welcome"), events(:welcome_send)
    assert_includes Event.search("WELCOME"), events(:welcome_send)
  end

  # No matches

  test "search returns empty when no matches" do
    assert_empty Event.search("nonexistent")
  end
end
