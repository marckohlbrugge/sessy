require "test_helper"

class SetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_to accounts(:instance)
    @source = accounts(:instance).sources.create!(name: "BetaList")
  end

  test "setup without a region shows the picker and a disabled Launch Stack control" do
    get source_setup_path(@source)

    assert_response :success
    assert_select "select[name='source[aws_region]']" do
      assert_select "option[value='']", text: /Choose the region/
      assert_select "option[value='eu-west-1']", text: "Europe (Ireland) (eu-west-1)"
      assert_select "option", count: Source::SES_REGIONS.size + 1
    end
    assert_select "[aria-disabled='true']", text: /Launch Stack/
    assert_select "a[href*='console.aws.amazon.com']", count: 0
    assert_match "&lt;region&gt;", response.body
  end

  test "setup with a region enables the link and fills the CLI snippets" do
    @source.update!(aws_region: "eu-west-1")

    get source_setup_path(@source)

    assert_response :success
    assert_select "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/'][target='_blank'][rel='noopener noreferrer']", text: /Launch Stack/
    assert_select "option[value='eu-west-1'][selected]"
    assert_match "--region eu-west-1", response.body
    assert_no_match "&lt;region&gt;", response.body
  end

  test "manual steps are collapsed and step 5 shows the default configuration set command" do
    get source_setup_path(@source)

    assert_select "details" do
      assert_select "summary", text: /Set up manually instead/
      assert_select "h2", text: /Create a Configuration Set/
      assert_select "h2", text: /Add an Event Destination/
    end
    assert_select "details h2", text: /Use the Configuration Set/, count: 0
    assert_match "put-email-identity-configuration-set-attributes", response.body
  end

  test "updating the region persists it and returns to the setup page with the link enabled" do
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

  test "a waiting source renders the status strip with Waiting for AWS active and polling on" do
    get source_setup_path(@source)

    assert_response :success
    assert_select "turbo-frame#setup_status[data-controller='poll'][data-poll-url-value='#{source_setup_path(@source)}']" do
      assert_select "[data-setup-status='waiting']"
      assert_select "[aria-live='polite']"
      assert_select "li[aria-current='step']", text: /Waiting for AWS/
      assert_select "li", text: /SNS connected/
      assert_select "li", text: /First event received/
    end
    assert_match "Click Launch Stack above", response.body
    assert_match "Stopped checking", response.body
  end

  test "a frame request returns only the status strip" do
    get source_setup_path(@source), headers: { "Turbo-Frame" => "setup_status" }

    assert_response :success
    assert_select "turbo-frame#setup_status"
    assert_select "h2", count: 0
    assert_select "select[name='source[aws_region]']", count: 0
    assert_select "details", count: 0
  end

  test "a connected source highlights SNS connected and names the configuration set" do
    @source.update!(subscribed_at: Time.current, sns_topic_arn: "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events")

    get source_setup_path(@source)

    assert_select "turbo-frame#setup_status[data-controller='poll']" do
      assert_select "[data-setup-status='connected']"
      assert_select "li[aria-current='step']", text: /SNS connected/
    end
    assert_select "turbo-frame#setup_status", text: /SNS is connected\. Send an email through the\s+betalist-ses\s+configuration set/
  end

  test "a complete source renders the summary, collapses Launch Stack, and stops polling" do
    @source.update!(aws_region: "eu-west-1", subscribed_at: 2.days.ago, first_event_at: 1.day.ago,
      sns_topic_arn: "arn:aws:sns:eu-west-1:000000000000:betalist-ses-events")

    get source_setup_path(@source)

    assert_response :success
    assert_select "turbo-frame#setup_status[data-controller='poll']", count: 0
    assert_select "turbo-frame#setup_status[data-poll-url-value]", count: 0
    assert_select "turbo-frame#setup_status[src]", count: 0
    assert_select "turbo-frame#setup_status [data-setup-status='complete']"
    assert_select "turbo-frame#setup_status li", count: 0
    assert_select "turbo-frame#setup_status", text: /Receiving events since/
    assert_select "turbo-frame#setup_status", text: /SNS connected/
    assert_select "turbo-frame#setup_status", text: /Europe \(Ireland\)/
    assert_select "turbo-frame#setup_status", text: /arn:aws:sns:eu-west-1:000000000000:betalist-ses-events/
    assert_select "details summary", text: /Connect SES to Sessy/
    assert_select "details summary", text: /Set up manually instead/
    assert_select "h2", text: /Use the Configuration Set/
    assert_select "details h2", text: /Use the Configuration Set/, count: 0
  end

  test "a backfilled complete source shows only what it knows" do
    @source.update!(first_event_at: 1.day.ago)

    get source_setup_path(@source)

    assert_select "turbo-frame#setup_status", text: /Receiving events since/ do |frames|
      text = frames.first.text.squish
      assert_no_match(/SNS connected/, text)
      assert_no_match(/Region/, text)
      assert_no_match(/Topic/, text)
      assert_no_match(/(·|\u00b7)\s*(·|\u00b7)/, text)
      assert_no_match(/(·|\u00b7)\s*\z/, text)
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
end
