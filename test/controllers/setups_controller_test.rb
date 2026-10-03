require "test_helper"

class SetupsControllerTest < ActionDispatch::IntegrationTest
  TOPIC_ARN = "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events"

  setup do
    sign_in_to accounts(:instance)
    @source = accounts(:instance).sources.create!(name: "BetaList")
  end

  test "a fresh source renders step 1 alone in a narrow column with everything secondary behind More options" do
    get source_setup_path(@source)

    assert_response :success
    assert_select "nav a", text: "Setup"
    assert_select ".max-w-xl [data-setup-step]", count: 1
    assert_progress step: 1
    assert_only_step 1

    assert_select "[data-setup-step='1']" do
      assert_select "h1", text: /Connect SES/
      assert_select "a[href^='https://console.aws.amazon.com/cloudformation/'][target='_blank'][rel='noopener noreferrer']", text: /Launch Stack/
      assert_select "button[data-action='clipboard#copy']", text: /Copy instructions for your AI agent/
      assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-status-value='waiting']", text: /Waiting for AWS/
      assert_select "details", count: 1
      assert_select "details > summary", text: "More options"
      assert_select "details select[name='source[aws_region]']" do
        assert_select "option[value='']", text: /Choose the region/
        assert_select "option[selected]", count: 0
        assert_select "option", count: Source::SES_REGIONS.size + 1
      end
      assert_select "details", text: /aws sesv2 create-configuration-set/
      assert_select "details", text: /ExistingConfigurationSetName/
      assert_select "details a[href*='aws-ses-setup.md']"
      assert_select "details a[href*='ses-security-best-practices.md']"
      assert_select "pre", text: /configuration_set_name:/, count: 0
    end
    assert_match "No AWS credentials", response.body
    assert_match "Not opening in the right region?", response.body
    assert_match "AWS_REGION", response.body
    assert_match "region you used last", response.body
    assert_no_match "Three steps, about 5 minutes", response.body
    assert_select "a", text: /Show step/, count: 0
  end

  test "the hidden agent prompt on step 1 carries this source's webhook URL and Launch Stack URL" do
    get source_setup_path(@source)

    assert_select "textarea[data-clipboard-target='source'][hidden][readonly]", count: 1 do |textareas|
      prompt = textareas.first.text
      assert_includes prompt, webhook_url(source_token: @source.token)
      assert_includes prompt, @source.config_set_name
      assert_includes prompt, @source.stack_name
      assert_includes prompt, "stacks/create/review"
      assert_includes prompt, "--region <region-code>"
    end
  end

  test "a chosen region keeps step 1 open and makes Launch Stack, the CLI commands and the prompt regional" do
    @source.update!(aws_region: "eu-west-1")

    get source_setup_path(@source)

    assert_response :success
    assert_only_step 1
    assert_select "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/']", text: /Launch Stack/
    assert_select "option[value='eu-west-1'][selected]"
    assert_match "Europe (Ireland)", response.body
    assert_match "--region eu-west-1", response.body
    assert_no_match "&lt;region", response.body
    assert_select "textarea[data-clipboard-target='source']" do |textareas|
      assert_includes textareas.first.text, "--region eu-west-1"
    end
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
    assert_match "updates automatically", response.body
  end

  test "a frame request returns only the status frame" do
    get source_setup_path(@source), headers: { "Turbo-Frame" => "setup_status" }

    assert_response :success
    assert_select "turbo-frame#setup_status"
    assert_select "h1", count: 0
    assert_select "select[name='source[aws_region]']", count: 0
    assert_select "details", count: 0
    assert_select "[data-setup-step]", count: 0
  end

  test "a connected source renders step 2 with one code sample at a time and a back link" do
    @source.record_subscription_confirmed(TOPIC_ARN)

    get source_setup_path(@source)

    assert_response :success
    assert_progress step: 2
    assert_only_step 2

    assert_select "[data-setup-step='2']" do
      assert_select "h1", text: /Send a test email/
      assert_select "[role='tablist'] button[role='tab']", count: 3
      assert_select "button[role='tab'][aria-selected='true']", text: "aws-sdk-sesv2", count: 1
      assert_select "[data-tabs-target='panel']", count: 3
      assert_select "[data-tabs-target='panel']:not([hidden]) pre", text: /configuration_set_name:/, count: 1
      assert_select "[data-tabs-target='panel'][hidden] pre", text: /X-SES-CONFIGURATION-SET/
      assert_select "[data-tabs-target='panel'][hidden] pre", text: /put-email-identity-configuration-set-attributes/
      assert_select "button[data-action='clipboard#copy']", text: /Copy instructions for your AI agent/
      assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-status-value='connected']", text: /Waiting for the first event/
      assert_select "details", count: 1
      assert_select "details > summary", text: "More options"
      assert_select "details", text: /list-subscriptions-by-topic/
      assert_select "select", count: 0
    end
    assert_select "a[href='#{source_setup_path(@source, step: 1)}']", text: /Show step 1/
    assert_select "a", text: /Launch Stack/, count: 0
    assert_select "textarea[data-clipboard-target='source']" do |textareas|
      assert_includes textareas.first.text, "X-SES-CONFIGURATION-SET"
      assert_includes textareas.first.text, "--region eu-west-1"
    end
  end

  test "a previous step reopens read-only without polling or the region form" do
    @source.record_subscription_confirmed(TOPIC_ARN)

    get source_setup_path(@source, step: 1)

    assert_response :success
    assert_progress step: 2
    assert_only_step 1
    assert_select "[data-setup-step='1'][data-setup-readonly]"
    assert_select "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/']", text: /Launch Stack/
    assert_select "turbo-frame#setup_status", count: 0
    assert_select "select", count: 0
    assert_match "Europe (Ireland)", response.body
    assert_select "a[href='#{source_setup_path(@source)}']", text: /Continue to step 2/
  end

  test "a step beyond the current one is clamped to the current step" do
    @source.record_subscription_confirmed(TOPIC_ARN)

    get source_setup_path(@source, step: 3)

    assert_only_step 2
    assert_select "[data-setup-readonly]", count: 0
    assert_select "turbo-frame#setup_status", count: 1
  end

  test "a complete source renders step 3 with a one-line summary and stops polling" do
    @source.update!(aws_region: "eu-west-1", subscribed_at: Time.zone.local(2026, 9, 30, 12), first_event_at: Time.zone.local(2026, 10, 1, 12), sns_topic_arn: TOPIC_ARN)

    get source_setup_path(@source)

    assert_response :success
    assert_progress step: 3
    assert_only_step 3

    assert_select "[data-setup-step='3']" do
      assert_select "h1"
      assert_select "[data-setup-summary]" do |summaries|
        text = summaries.first.text.squish
        assert_match(/Connected .*Sep 30, 2026/, text)
        assert_match(/Europe \(Ireland\)/, text)
        assert_match(/First event .*Oct 1, 2026/, text)
        assert_no_match(/arn:/, text)
      end
      assert_select "a[href='#{source_path(@source)}']", text: /Overview/
      assert_select "turbo-frame#setup_status", count: 0
      assert_select "details", count: 0
    end
    assert_select "[data-controller='poll']", count: 0
    assert_select "a[href='#{source_setup_path(@source, step: 2)}']", text: /Show step 2/
  end

  test "a backfilled complete source shows only what it knows" do
    @source.update!(first_event_at: 1.day.ago)

    get source_setup_path(@source)

    assert_select "[data-setup-summary]" do |summaries|
      text = summaries.first.text.squish
      assert_match(/First event/, text)
      assert_no_match(/Connected|Region|arn:/, text)
      assert_no_match(/(·|\u00b7)\s*(·|\u00b7)/, text)
      assert_no_match(/\A\s*(·|\u00b7)|(·|\u00b7)\s*\z/, text)
    end
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

  # Pills: three segments, the first `step` filled; the label names the step.
  def assert_progress(step:)
    assert_select "nav[aria-label='Setup progress']" do
      assert_select "ol li", count: 3
      assert_select "ol li[data-filled]", count: step
      assert_select "ol li[aria-current='step']", count: 1
      assert_select "ol li:nth-child(#{step})[aria-current='step']"
      assert_select "[data-setup-progress-label]", text: "Step #{step} of 3"
    end
  end

  # Exactly one step is rendered, so the polled frame can never appear twice.
  def assert_only_step(number)
    assert_select "[data-setup-step]", count: 1
    assert_select "[data-setup-step='#{number}']"
  end
end
