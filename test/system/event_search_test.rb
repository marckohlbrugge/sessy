require "application_system_test_case"

class EventSearchTest < ApplicationSystemTestCase
  test "search field keeps focus while results update" do
    visit source_events_path(sources(:betalist))

    fill_in "query", with: "marc"

    assert_no_text "john@example.com"
    assert_text "marc@example.com"

    assert_equal "query", page.evaluate_script("document.activeElement.id")
  end

  test "search field resets when navigating to an unfiltered page" do
    visit source_events_path(sources(:betalist))

    fill_in "query", with: "marc"
    assert_no_text "john@example.com"

    click_link "Activity"
    assert_text "john@example.com"

    assert_equal "", find_field("query").value
  end
end
