require "test_helper"

class SourceAgentInstructionsTest < ActiveSupport::TestCase
  WEBHOOK_URL = "https://sessy.example.com/webhooks/abc123"
  LAUNCH_STACK_URL = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?stackName=sessy-betalist-1"

  setup do
    @source = sources(:betalist)
  end

  test "the connect prompt carries the source's real values" do
    prompt = instructions.connect

    assert_includes prompt, WEBHOOK_URL
    assert_includes prompt, LAUNCH_STACK_URL
    assert_includes prompt, @source.config_set_name
    assert_includes prompt, @source.sns_topic_name
    assert_includes prompt, @source.stack_name
    assert_includes prompt, "aws sesv2 create-configuration-set"
    assert_includes prompt, "aws sns create-topic"
    assert_includes prompt, "aws sns subscribe"
    assert_includes prompt, "create-configuration-set-event-destination"
    assert_includes prompt, "get_source_setup"
    assert_match(/SNS connected/i, prompt)
  end

  test "a known region fills every command and leaves no placeholder" do
    @source.update!(aws_region: "eu-west-1")

    prompt = instructions.connect

    assert_includes prompt, "--region eu-west-1"
    assert_includes prompt, "arn:aws:sns:eu-west-1:<account-id>:#{@source.sns_topic_name}"
    assert_no_match(/<region/, prompt)
    assert_no_match(/region your app sends/, prompt)
  end

  test "an unknown region tells the agent which region to use instead of guessing" do
    prompt = instructions.connect

    assert_includes prompt, "--region <region-code>"
    assert_includes prompt, "arn:aws:sns:<region-code>:<account-id>:#{@source.sns_topic_name}"
    assert_no_match(/<region>/, prompt)
    assert_match(/region your app sends/, prompt)
  end

  test "the send prompt covers the three ways to attach the configuration set" do
    prompt = instructions.send_test_email

    assert_includes prompt, @source.config_set_name
    assert_includes prompt, "configuration_set_name:"
    assert_includes prompt, "X-SES-CONFIGURATION-SET"
    assert_includes prompt, "put-email-identity-configuration-set-attributes"
    assert_match(/first event/i, prompt)
    assert_no_match(/<account-id>/, prompt)
    assert_no_match(/<region>/, prompt)
  end

  private

  def instructions
    Source::AgentInstructions.new(@source, webhook_url: WEBHOOK_URL, launch_stack_url: LAUNCH_STACK_URL)
  end
end
