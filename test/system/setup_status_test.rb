require "application_system_test_case"

class SetupStatusTest < ApplicationSystemTestCase
  TOPIC_ARN = "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events"

  test "a confirmed subscription advances the open step from 1 to 2 without navigating" do
    source = sources(:betalist)
    visit source_setup_path(source)

    assert_selector "nav[aria-label='Setup progress'] li[aria-current='step']", text: "Connect SES"
    assert_selector "[data-setup-step='1'][data-step-state='current']"
    assert_text "Waiting for AWS"
    assert_no_selector "pre", text: "X-SES-CONFIGURATION-SET"

    source.record_subscription_confirmed(TOPIC_ARN)

    assert_selector "nav[aria-label='Setup progress'] li[aria-current='step']", text: "Send a test email", wait: 10
    assert_selector "details[data-setup-step='1'][data-step-state='done'] summary", text: /Connected .* Europe \(Ireland\) \(eu-west-1\)/
    assert_selector "[data-setup-step='2'][data-step-state='current']"
    assert_selector "pre", text: "X-SES-CONFIGURATION-SET"
    assert_text "Waiting for the first event"
    assert_equal source_setup_path(source), current_path
    assert_equal "eu-west-1", source.reload.aws_region
  end

  test "the first event advances the open step from 2 to 3 and stops polling" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago, sns_topic_arn: TOPIC_ARN, aws_region: "eu-west-1")
    visit source_setup_path(source)

    assert_selector "[data-setup-step='2'][data-step-state='current']"

    source.update!(first_event_at: Time.current)

    assert_selector "[data-setup-step='3'][data-step-state='current']", text: "Receiving events since", wait: 10
    assert_selector "details[data-setup-step='2'][data-step-state='done'] summary", text: "First event received"
    assert_selector "nav[aria-label='Setup progress'] li", text: "Done:", visible: :all, count: 3
    assert_no_selector "turbo-frame#setup_status[data-controller]"
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
    assert_selector "[data-setup-step='1'][data-step-state='current']"

    within("turbo-frame#setup_status") { click_link "Reload" }

    assert_selector "[data-setup-step='2'][data-step-state='current']", wait: 10
    assert_no_text "Stopped checking"
    assert_equal source_setup_path(source), current_path
  end
end
