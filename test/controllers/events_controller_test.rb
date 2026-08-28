require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
    @source = sources(:betalist)
  end

  test "index renders filter chips with counts" do
    get source_events_path(@source)

    assert_response :success
    assert_match "marc@example.com", response.body
    # 2 sends in the default window (welcome + digest)
    assert_select "input[name='event_types[]'][value=send] ~ span", text: /Sent\s*2/
  end

  test "index with search skips chip counts and still paginates" do
    get source_events_path(@source, query: "marc")

    assert_response :success
    assert_match "marc@example.com", response.body
    assert_no_match "john@example.com", response.body
    assert_select "input[name='event_types[]'][value=send] ~ span", text: /\A\s*Sent\s*\z/
  end

  test "index with search paginates past the first page" do
    message = messages(:welcome)
    60.times do |i|
      message.events.create!(source: @source, ses_message_id: message.ses_message_id, event_type: "Send",
        event_at: 1.hour.ago + i.seconds, recipient_email: "searchme-#{i}@example.com")
    end

    get source_events_path(@source, query: "searchme")
    assert_response :success
    assert_select "tbody tr", 50

    next_url = css_select("a[aria-label='Next']").first["href"]
    get next_url
    assert_response :success
    assert_select "tbody tr", 10
  end

  test "index paginates past the first page using the derived count" do
    message = messages(:welcome)
    60.times do |i|
      message.events.create!(source: @source, ses_message_id: message.ses_message_id, event_type: "Send",
        event_at: 1.hour.ago + i.seconds, recipient_email: "bulk-#{i}@example.com")
    end

    get source_events_path(@source)
    assert_response :success
    assert_select "tbody tr", 50

    next_url = css_select("a[aria-label='Next']").first["href"]
    get next_url
    assert_response :success
    assert_select "tbody tr", 13 # 60 created + 3 fixture events in the window
  end

  test "index with bounce subtype filter renders matching events" do
    message = messages(:welcome)
    message.events.create!(source: @source, ses_message_id: message.ses_message_id, event_type: "Bounce",
      bounce_type: "Permanent", event_at: 1.hour.ago, recipient_email: "bounced@example.com")

    get source_events_path(@source, event_types: [ "bounce" ], bounce_types: [ "permanent" ])

    assert_response :success
    assert_match "bounced@example.com", response.body
    assert_no_match "marc@example.com", response.body
  end

  test "index caches filter chip counts while rows stay live" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    get source_events_path(@source)
    assert_select "input[name='event_types[]'][value=send] ~ span", text: /Sent\s*2/

    message = messages(:welcome)
    message.events.create!(source: @source, ses_message_id: message.ses_message_id, event_type: "Send",
      event_at: 1.hour.ago, recipient_email: "fresh@example.com")

    get source_events_path(@source)
    assert_response :success
    assert_match "fresh@example.com", response.body # rows are queried live
    assert_select "input[name='event_types[]'][value=send] ~ span", text: /Sent\s*2/ # counts come from cache
  ensure
    Rails.cache = original_cache
  end

  test "index with event type filter shows only matching events" do
    get source_events_path(@source, event_types: [ "delivery" ])

    assert_response :success
    assert_match "Delivered", response.body
    assert_no_match "john@example.com", response.body # john only has a send
  end

  test "index csv exports filtered events" do
    get source_events_path(@source, format: :csv, query: "marc")

    assert_response :success
    assert_match "marc@example.com", response.body
    assert_no_match "john@example.com", response.body
  end
end
