require "test_helper"

class SetupsControllerTest < ActionDispatch::IntegrationTest
  TOPIC_ARN = "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events"

  setup do
    sign_in_to accounts(:instance)
    @source = accounts(:instance).sources.create!(name: "BetaList")
  end

  test "a fresh source opens step 1 only, with a working region-less Launch Stack and the region as an override" do
    get source_setup_path(@source)

    assert_response :success
    assert_progress current: "Connect SES"
    assert_open_step 1

    assert_select "[data-setup-step='1'][data-step-state='current']" do
      assert_select "a[href^='https://console.aws.amazon.com/cloudformation/'][target='_blank'][rel='noopener noreferrer']", text: /Launch Stack/
      assert_select "[aria-disabled='true']", count: 0
      assert_select "select[name='source[aws_region]']" do
        assert_select "option[value='']", text: /Choose the region/
        assert_select "option[selected]", count: 0
        assert_select "option", count: Source::SES_REGIONS.size + 1
      end
      assert_select "details summary", text: /Set up manually instead/
      assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-status-value='waiting']"
    end
    assert_match "Not opening in the right region?", response.body
    assert_match "AWS_REGION", response.body
    assert_match "email-smtp.eu-west-1.amazonaws.com", response.body
    assert_match "region you used last", response.body
    assert_match "&lt;region&gt;", response.body

    assert_select "[data-setup-step='2'][data-step-state='upcoming']" do
      assert_select "pre", count: 0
    end
    assert_select "[data-setup-step='3'][data-step-state='upcoming']"
  end

  test "a chosen region keeps step 1 open and makes Launch Stack and the CLI snippets regional" do
    @source.update!(aws_region: "eu-west-1")

    get source_setup_path(@source)

    assert_response :success
    assert_open_step 1
    assert_select "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/']", text: /Launch Stack/
    assert_select "option[value='eu-west-1'][selected]"
    assert_match "Opens the CloudFormation console in Europe (Ireland)", response.body
    assert_match "--region eu-west-1", response.body
    assert_no_match "&lt;region&gt;", response.body
  end

  test "updating the region persists it and returns to the setup page with the regional link" do
    patch source_setup_path(@source), params: { source: { aws_region: "us-east-1", name: "Hijacked" } }

    assert_redirected_to source_setup_path(@source)
    @source.reload
    assert_equal "us-east-1", @source.aws_region
    assert_equal "BetaList", @source.name

    follow_redirect!
    assert_select "a[href^='https://us-east-1.console.aws.amazon.com/cloudformation/']", text: /Launch Stack/
  end

  test "an unknown region is rejected and the setup page re-renders" do
    patch source_setup_path(@source), params: { source: { aws_region: "mars-north-1" } }

    assert_response :unprocessable_entity
    assert_nil @source.reload.aws_region
    assert_select "select[name='source[aws_region]']"
    assert_match "not included in the list", response.body
  end

  test "a waiting source polls the status frame with the waiting guidance" do
    get source_setup_path(@source)

    assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-url-value='#{source_setup_path(@source)}']" do
      assert_select "[data-setup-status='waiting'][aria-live='polite']"
      assert_select "[data-poll-target='paused'][hidden]", text: /Stopped checking/
    end
    assert_match "Waiting for AWS", response.body
    assert_match "updates automatically", response.body
  end

  test "a frame request returns only the status frame" do
    get source_setup_path(@source), headers: { "Turbo-Frame" => "setup_status" }

    assert_response :success
    assert_select "turbo-frame#setup_status"
    assert_select "h2", count: 0
    assert_select "select[name='source[aws_region]']", count: 0
    assert_select "details", count: 0
    assert_select "[data-setup-step]", count: 0
  end

  test "a connected source collapses step 1 to a summary with the inferred region and opens step 2" do
    @source.record_subscription_confirmed(TOPIC_ARN)

    get source_setup_path(@source)

    assert_response :success
    assert_progress current: "Send a test email"
    assert_open_step 2

    assert_select "details[data-setup-step='1'][data-step-state='done']" do
      assert_select "summary", text: /Connected/
      assert_select "summary", text: /Europe \(Ireland\)/
      assert_select "summary", text: /#{Regexp.escape(TOPIC_ARN)}/
      assert_select "a", text: /Launch Stack/
    end
    assert_select "[data-setup-step='2'][data-step-state='current']" do
      assert_select "pre", minimum: 3
      assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-status-value='connected']" do
        assert_select "[data-setup-status='connected']"
      end
    end
    assert_select "[data-setup-step='2']", text: /Waiting for the first event/
    assert_match "put-email-identity-configuration-set-attributes", response.body
    assert_select "[data-setup-step='3'][data-step-state='upcoming']"
  end

  test "a complete source collapses steps 1 and 2, opens step 3, and stops polling" do
    @source.update!(aws_region: "eu-west-1", subscribed_at: 2.days.ago, first_event_at: 1.day.ago, sns_topic_arn: TOPIC_ARN)

    get source_setup_path(@source)

    assert_response :success
    assert_progress current: nil
    assert_select "nav[aria-label='Setup progress'] li", text: /Done:/, count: 3
    assert_open_step 3

    assert_select "details[data-setup-step='1'][data-step-state='done'] summary", text: /Connected/
    assert_select "details[data-setup-step='2'][data-step-state='done'] summary", text: /First event received/
    assert_select "[data-setup-step='3'][data-step-state='current']" do
      assert_select "turbo-frame#setup_status", text: /Receiving events since/
      assert_select "turbo-frame#setup_status[data-controller]", count: 0
      assert_select "turbo-frame#setup_status[data-poll-url-value]", count: 0
      assert_select "turbo-frame#setup_status[src]", count: 0
      assert_select "a[href='#{source_events_path(@source)}']"
    end
  end

  test "a backfilled complete source shows only what it knows" do
    @source.update!(first_event_at: 1.day.ago)

    get source_setup_path(@source)

    assert_select "details[data-setup-step='1'] summary" do |summaries|
      text = summaries.first.text.squish
      assert_match(/Connected/, text)
      assert_no_match(/Region|Topic|arn:/, text)
      assert_no_match(/(·|\u00b7)\s*(·|\u00b7)/, text)
      assert_no_match(/(·|\u00b7)\s*\z/, text)
    end
    assert_select "turbo-frame#setup_status", text: /Receiving events since/
  end

  test "another account's source setup is not reachable" do
    other = Account.create!(name: "Other Co", approved_at: Time.current).sources.create!(name: "OtherApp")

    get source_setup_path(other)
    assert_response :not_found

    patch source_setup_path(other), params: { source: { aws_region: "us-east-1" } }
    assert_response :not_found
    assert_nil other.reload.aws_region
  end

  private

  def assert_progress(current:)
    assert_select "nav[aria-label='Setup progress'] ol li", count: 3
    if current
      assert_select "nav[aria-label='Setup progress'] li[aria-current='step']", text: /#{current}/, count: 1
    else
      assert_select "nav[aria-label='Setup progress'] li[aria-current='step']", count: 0
    end
  end

  def assert_open_step(number)
    assert_select "[data-step-state='current']", count: 1
    assert_select "[data-setup-step='#{number}'][data-step-state='current']"
  end
end
