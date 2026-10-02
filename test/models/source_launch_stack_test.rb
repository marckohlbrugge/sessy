require "test_helper"

class Source::LaunchStackTest < ActiveSupport::TestCase
  WEBHOOK = "https://app.example.com/webhooks/abc-123"

  test "launch URL opens the region's console with the template and parameters prefilled" do
    source = create_source("BetaList", aws_region: "eu-west-1")

    url = source.launch_stack_url(webhook_url: WEBHOOK)

    assert url.start_with?("https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?")
    query = Rack::Utils.parse_query(url.split("review?").last)
    assert_equal Rails.configuration.x.cloudformation_template_url, query["templateURL"]
    assert_equal "sessy-betalist-#{source.id}", query["stackName"]
    assert_equal WEBHOOK, query["param_WebhookUrl"]
    assert_equal "betalist-ses", query["param_ConfigurationSetName"]
    assert_equal "betalist-ses-events", query["param_TopicName"]
    assert_equal "", query["param_ExistingConfigurationSetName"]
    assert_includes url, "templateURL=https%3A%2F%2F"
  end

  test "non-Latin names fall back to source-<id> derived names with no empty segments" do
    source = create_source("日本語", aws_region: "ap-northeast-1")

    assert_equal "sessy-source-#{source.id}", source.stack_name
    assert_equal "source-#{source.id}-ses", source.config_set_name
    assert_equal "source-#{source.id}-ses-events", source.sns_topic_name
    assert_no_match(/--|-\z|\A-/, source.stack_name)
  end

  test "stack name maps underscores to hyphens and keeps the configuration set name as-is" do
    source = create_source("prod_east")

    assert_equal "sessy-prod-east-#{source.id}", source.stack_name
    assert_equal "prod_east-ses", source.config_set_name
  end

  test "stack name is capped at 128 characters and still ends in the id" do
    source = create_source("a" * 200)

    assert_operator source.stack_name.length, :<=, 128
    assert source.stack_name.end_with?("-#{source.id}")
    assert_match(/\A[a-zA-Z][-a-zA-Z0-9]*\z/, source.stack_name)
  end

  test "configuration set and topic names fit SES's 64-character limit without a dangling hyphen" do
    source = create_source(("word " * 40).strip)

    assert_operator source.config_set_name.length, :<=, 64
    assert_operator source.sns_topic_name.length, :<=, 64
    assert_match(/\A[a-z0-9]+(-[a-z0-9]+)*-ses-events\z/, source.sns_topic_name)
  end

  test "launch URL without a region opens the console's global host with the same parameters" do
    source = create_source("BetaList")

    url = source.launch_stack_url(webhook_url: WEBHOOK)

    assert url.start_with?("https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?")
    assert_no_match(/region=/, url)
    query = Rack::Utils.parse_query(url.split("review?").last)
    assert_equal "sessy-betalist-#{source.id}", query["stackName"]
    assert_equal WEBHOOK, query["param_WebhookUrl"]
    assert_equal "betalist-ses", query["param_ConfigurationSetName"]
  end

  test "a stored region outside the SES list is never interpolated into the URL" do
    source = create_source("BetaList")
    Source.where(id: source.id).update_all(aws_region: "evil.example.com/")

    url = source.reload.launch_stack_url(webhook_url: WEBHOOK)

    assert url.start_with?("https://console.aws.amazon.com/cloudformation/")
    assert_no_match(/evil/, url)
  end

  test "region_from_topic_arn reads a known SES region out of an SNS topic ARN" do
    assert_equal "eu-west-1", Source.region_from_topic_arn("arn:aws:sns:eu-west-1:000000000000:betalist-ses-events")
    assert_equal "us-east-1", Source.region_from_topic_arn("arn:aws:sns:us-east-1:1:first")
  end

  test "region_from_topic_arn is nil for anything but an SNS ARN in a known region" do
    [
      "arn:aws:sqs:eu-west-1:000000000000:queue",
      "arn:aws:sns:mars-north-1:000000000000:topic",
      "arn:aws-cn:sns:cn-north-1:000000000000:topic",
      "eu-west-1",
      "garbage",
      "",
      nil
    ].each do |arn|
      assert_nil Source.region_from_topic_arn(arn), "expected nil for #{arn.inspect}"
    end
  end

  test "region must be an SES region; blank is stored as nil" do
    source = create_source("BetaList")

    assert source.update(aws_region: "us-east-1")
    assert source.update(aws_region: "")
    assert_nil source.aws_region
    assert_not source.update(aws_region: "mars-north-1")
    assert_includes source.errors[:aws_region], "is not included in the list"
  end

  test "SES_REGIONS lists the 27 commercial regions with display names" do
    assert_equal 27, Source::SES_REGIONS.size
    assert_equal "Europe (Ireland)", Source::SES_REGIONS["eu-west-1"]
    assert_equal "us-east-2", Source::SES_REGIONS.keys.first
  end

  private

  def create_source(name, **attrs)
    accounts(:instance).sources.create!(name: name, **attrs)
  end
end
