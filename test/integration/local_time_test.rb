require "test_helper"

class LocalTimeTest < ActionDispatch::IntegrationTest
  test "message show page renders local_time elements for timestamps" do
    message = messages(:welcome)

    get source_message_path(message.source, message)

    assert_response :success
    assert_select "time[data-local='time']", minimum: 1
  end

  test "events index renders local_time elements for event timestamps" do
    source = sources(:betalist)

    get source_events_path(source)

    assert_response :success
    assert_select "time[data-local='time']", minimum: 1
  end
end
