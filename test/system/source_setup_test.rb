require "application_system_test_case"

class SourceSetupTest < ApplicationSystemTestCase
  test "a fresh source shows step 1 alone with Launch Stack; the region picker inside More options makes it regional" do
    source = sources(:betalist)
    visit source_setup_path(source)

    assert_selector "[data-setup-step]", count: 1
    assert_selector "[data-setup-step='1']"
    assert_selector "nav[aria-label='Setup progress'] li[data-filled]", count: 1
    assert_text "Step 1 of 3"
    link = find_link("Launch Stack")
    assert link[:href].start_with?("https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?")
    assert_equal "_blank", link[:target]
    assert_text "the AWS region you used last"
    assert_button "Copy instructions for your AI agent"
    assert_no_text "Not opening in the right region?"
    assert_no_selector "pre"

    find("summary", text: "More options").click
    assert_text "Not opening in the right region?"
    assert_text "--region <region-code>"
    select "Europe (Ireland) (eu-west-1)", from: "source_#{source.id}_aws_region"

    assert_selector "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/']", text: "Launch Stack"
    assert_text "(Europe (Ireland))"
    assert_selector "[data-setup-step='1']"
    assert_equal "eu-west-1", source.reload.aws_region

    # More options stays open after the save, so the select keeps focus and the commands show the change.
    assert_selector "details[data-setup-more][open]"
    assert_equal "source_#{source.id}_aws_region", page.evaluate_script("document.activeElement.id")
    assert_text "--region eu-west-1"
    assert_no_text "--region <region-code>"

    visit source_setup_path(source)
    assert_no_selector "details[data-setup-more][open]"
  end

  test "the hidden agent prompt carries this source's webhook URL" do
    source = sources(:betalist)
    visit source_setup_path(source)

    prompt = find("textarea[data-clipboard-target='source']", visible: false).value
    assert_includes prompt, webhook_url(source_token: source.token, host: Capybara.current_session.server.host, port: Capybara.current_session.server.port)
    assert_includes prompt, source.config_set_name
    assert_includes prompt, "stacks/create/review"
  end

  test "the code-sample toggle on step 2 shows one sample at a time" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago, aws_region: "eu-west-1")
    visit source_setup_path(source)

    assert_selector "[data-setup-step='2']"
    assert_text "Step 2 of 3"
    assert_selector "pre", count: 1
    assert_selector "pre", text: "configuration_set_name:"

    click_button "aws-actionmailer-ses"
    assert_selector "pre", count: 1
    assert_selector "pre", text: "X-SES-CONFIGURATION-SET"
    assert_selector "button[role='tab'][aria-selected='true']", text: "aws-actionmailer-ses", count: 1

    click_button "AWS CLI"
    assert_selector "pre", count: 1
    assert_selector "pre", text: "put-email-identity-configuration-set-attributes"
    assert_text "--region eu-west-1"
  end

  test "an earlier step reopens read-only and leads back to the current one" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago, aws_region: "eu-west-1")
    visit source_setup_path(source)

    assert_no_text "Launch Stack"
    click_link "Show step 1"

    assert_selector "[data-setup-step='1'][data-setup-readonly]"
    assert_link "Launch Stack"
    assert_text "Step 2 of 3"
    assert_no_selector "turbo-frame#setup_status"
    click_link "Continue to step 2"

    assert_selector "[data-setup-step='2']"
    assert_equal source_setup_path(source), current_path
  end
end
