require "application_system_test_case"

class SourceSetupTest < ApplicationSystemTestCase
  test "choosing a region enables Launch Stack and fills the CLI snippets" do
    source = sources(:betalist)
    visit source_setup_path(source)

    assert_text "Choose your SES region first"
    assert_no_selector "a", text: "Launch Stack"
    assert_text "--region <region>"

    select "Europe (Ireland) (eu-west-1)", from: "source_#{source.id}_aws_region"

    link = find_link("Launch Stack")
    assert link[:href].start_with?("https://eu-west-1.console.aws.amazon.com/cloudformation/")
    assert_equal "_blank", link[:target]
    assert_text "Opens the CloudFormation console in Europe (Ireland)"
    assert_text "--region eu-west-1"
    assert_no_text "--region <region>"
    assert_equal "eu-west-1", source.reload.aws_region
    assert_equal "source_#{source.id}_aws_region", page.evaluate_script("document.activeElement.id")
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
end
