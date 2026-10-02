require "application_system_test_case"

class SourceSetupTest < ApplicationSystemTestCase
  test "a fresh source opens step 1 with a working Launch Stack; picking a region makes it regional" do
    source = sources(:betalist)
    visit source_setup_path(source)

    assert_selector "[data-step-state='current']", count: 1
    assert_selector "[data-setup-step='1'][data-step-state='current']"
    link = find_link("Launch Stack")
    assert link[:href].start_with?("https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?")
    assert_equal "_blank", link[:target]
    assert_text "Opens the CloudFormation console in the AWS region you used last"
    assert_text "Not opening in the right region? Pick it here."
    assert_no_selector "pre", text: "aws-sdk-sesv2"

    select "Europe (Ireland) (eu-west-1)", from: "source_#{source.id}_aws_region"

    assert_selector "a[href^='https://eu-west-1.console.aws.amazon.com/cloudformation/']", text: "Launch Stack"
    assert_text "Opens the CloudFormation console in Europe (Ireland)"
    assert_selector "[data-setup-step='1'][data-step-state='current']"
    assert_equal "eu-west-1", source.reload.aws_region
    assert_equal "source_#{source.id}_aws_region", page.evaluate_script("document.activeElement.id")

    find("summary", text: "Set up manually instead").click
    assert_text "a. Create a Configuration Set"
    assert_text "--region eu-west-1"
    assert_no_text "--region <region>"
  end

  test "changing the region again swaps the link and keeps the manual steps collapsed by default" do
    source = sources(:betalist)
    source.update!(aws_region: "eu-west-1")
    visit source_setup_path(source)

    select "US East (Ohio) (us-east-2)", from: "source_#{source.id}_aws_region"

    assert_selector "a[href^='https://us-east-2.console.aws.amazon.com/']", text: "Launch Stack"
    assert_no_selector "a[href^='https://eu-west-1.console.aws.amazon.com/']"
    assert_equal "us-east-2", source.reload.aws_region

    assert_no_text "Create a Configuration Set"
    find("summary", text: "Set up manually instead").click
    assert_text "a. Create a Configuration Set"
    assert_text "aws ses create-configuration-set"
  end

  test "a done step can be reopened to show its content" do
    source = sources(:betalist)
    source.update!(subscribed_at: 1.hour.ago, aws_region: "eu-west-1")
    visit source_setup_path(source)

    assert_no_text "Opens the CloudFormation console"
    find("details[data-setup-step='1'] summary").click
    assert_text "Opens the CloudFormation console in Europe (Ireland)"
    assert_selector "[data-setup-step='2'][data-step-state='current']"
  end
end
