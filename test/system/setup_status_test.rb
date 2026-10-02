require "application_system_test_case"

class SetupStatusTest < ApplicationSystemTestCase
  test "the status strip advances from waiting to connected without navigating" do
    source = sources(:betalist)
    visit source_setup_path(source)

    within "turbo-frame#setup_status" do
      assert_selector "li[aria-current='step']", text: "Waiting for AWS"
      assert_text "Click Launch Stack above"
    end

    source.update!(subscribed_at: Time.current, sns_topic_arn: "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events")

    within "turbo-frame#setup_status" do
      assert_selector "li[aria-current='step']", text: "SNS connected", wait: 10
      assert_text "SNS is connected. Send an email through the betalist-ses configuration set to finish."
    end
    assert_equal source_setup_path(source), current_path
    assert_selector "h2", text: "2. Connect SES to Sessy"
  end

  test "the strip pauses once its budget is spent and Reload resumes checking" do
    source = sources(:betalist)
    visit source_setup_path(source)

    within "turbo-frame#setup_status" do
      assert_no_text "Stopped checking"
    end

    # Spend the 30-minute budget without waiting for it.
    page.execute_script(<<~JS)
      const frame = document.querySelector("turbo-frame#setup_status")
      window.Stimulus.getControllerForElementAndIdentifier(frame, "poll").deadline = 0
    JS

    within "turbo-frame#setup_status" do
      assert_text "Stopped checking. Reload to check again.", wait: 10
    end

    source.update!(subscribed_at: Time.current)
    within "turbo-frame#setup_status" do
      assert_selector "li[aria-current='step']", text: "Waiting for AWS" # paused: no poll picked it up

      click_link "Reload"

      assert_selector "li[aria-current='step']", text: "SNS connected", wait: 10
      assert_no_text "Stopped checking"
    end
    assert_equal source_setup_path(source), current_path
  end

  test "the strip stops polling once the first event is recorded" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago)
    visit source_setup_path(source)

    within "turbo-frame#setup_status" do
      assert_selector "li[aria-current='step']", text: "SNS connected"
    end

    source.update!(first_event_at: Time.current)

    within "turbo-frame#setup_status" do
      assert_text "Receiving events since", wait: 10
      assert_no_selector "li"
    end
  end
end
