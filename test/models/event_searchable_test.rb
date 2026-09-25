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

  # Result shape

  test "search returns an event once when both its recipient and subject match" do
    messages(:welcome).update!(subject: "Your report, marc@example.com")

    assert_equal [ events(:welcome_send) ], Event.search("marc@example.com").where(event_type: "Send").to_a
  end

  test "search composes with scopes, filters, and pagination" do
    events = sources(:betalist).events.search("example.com").filter_by_params({}).reverse_chronologically.includes(:message)

    assert_equal [ events(:welcome_send), events(:welcome_delivery), events(:digest_send) ].sort_by(&:id), events.to_a.sort_by(&:id)
    assert_equal [ events(:digest_send) ], events.offset(2).limit(1).to_a
    assert_equal 3, events.count
  end

  test "search treats LIKE wildcards literally" do
    assert_empty Event.search("%")
    assert_empty Event.search("marc_example")
  end
end
