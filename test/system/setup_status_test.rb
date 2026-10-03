require "application_system_test_case"

class SetupStatusTest < ApplicationSystemTestCase
  TOPIC_ARN = "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events"

  test "a confirmed subscription advances from step 1 to step 2 without navigating" do
    source = sources(:betalist)
    visit source_setup_path(source)

    assert_text "Step 1 of 3"
    assert_selector "[data-setup-step='1']"
    assert_text "Waiting for AWS"
    assert_no_selector "pre"

    source.record_subscription_confirmed(TOPIC_ARN)

    assert_text "Step 2 of 3", wait: 10
    assert_selector "[data-setup-step='2']"
    assert_no_selector "[data-setup-step='1']"
    assert_selector "pre", text: "configuration_set_name:"
    assert_text "Waiting for the first event"
    assert_includes find("textarea[data-clipboard-target='source']", visible: false).value, "--region eu-west-1"
    assert_equal source_setup_path(source), current_path
    assert_equal "eu-west-1", source.reload.aws_region
  end

  test "the first event advances from step 2 to step 3 and stops polling" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago, sns_topic_arn: TOPIC_ARN, aws_region: "eu-west-1")
    visit source_setup_path(source)

    assert_selector "[data-setup-step='2']"

    source.update!(first_event_at: Time.current)

    assert_selector "[data-setup-step='3']", text: "all set", wait: 10
    assert_text "Step 3 of 3"
    assert_selector "nav[aria-label='Setup progress'] li[data-filled]", count: 3
    assert_selector "[data-setup-summary]", text: /Connected .* Europe \(Ireland\) .* First event/
    assert_link "Go to Overview"
    assert_no_selector "turbo-frame#setup_status"
    assert_equal source_setup_path(source), current_path
  end

  test "polling pauses once its budget is spent and Reload resumes checking" do
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

    source.record_subscription_confirmed(TOPIC_ARN)
    sleep 0.5 # paused: no poll picks the change up
    assert_selector "[data-setup-step='1']"

    within("turbo-frame#setup_status") { click_link "Reload" }

    assert_selector "[data-setup-step='2']", wait: 10
    assert_no_text "Stopped checking"
    assert_equal source_setup_path(source), current_path
  end
end
