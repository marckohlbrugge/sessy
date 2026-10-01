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
      assert_select "option", count: 28
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

  test "another account's source setup is not reachable" do
    other = Account.create!(name: "Other Co", approved_at: Time.current).sources.create!(name: "OtherApp")

    get source_setup_path(other)
    assert_response :not_found

    patch source_setup_path(other), params: { source: { aws_region: "us-east-1" } }
    assert_response :not_found
    assert_nil other.reload.aws_region
  end
end
