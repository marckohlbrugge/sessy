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

  test "launch URL is nil without a region or with a region outside the SES list" do
    source = create_source("BetaList")
    assert_nil source.launch_stack_url(webhook_url: WEBHOOK)

    Source.where(id: source.id).update_all(aws_region: "evil.example.com/")
    assert_nil source.reload.launch_stack_url(webhook_url: WEBHOOK)
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
