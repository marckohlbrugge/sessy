require "test_helper"
require "digest"
require "net/http"

# Guards the structure of the Launch Stack template and reminds the
# publisher that a changed template ships under a new S3 key. The
# template's real validation is `aws cloudformation validate-template` and a
# sandbox stack; see docs/hosted-launch-runbook.md.
class CloudformationTemplateTest < ActiveSupport::TestCase
  TEMPLATE_PATH = Rails.root.join("config/cloudformation/sessy-ses.yml")

  # SHA-256 of the template body as published at the current versioned key.
  # When this test fails after editing the template: publish the new body
  # under a new key, point config.x.cloudformation_template_url at it, then
  # update this constant.
  PUBLISHED_TEMPLATE_SHA256 = "661cce20cfa60a62b50c91179e3ab9efc7104aabf2635ad2676c1dc47750845b"

  EVENT_TYPES = %w[SEND REJECT BOUNCE COMPLAINT DELIVERY OPEN CLICK RENDERING_FAILURE DELIVERY_DELAY SUBSCRIPTION]

  test "template declares exactly the quick-create parameters" do
    assert_equal %w[ConfigurationSetName ExistingConfigurationSetName TopicName WebhookUrl], template["Parameters"].keys.sort
    assert_equal "", template.dig("Parameters", "ExistingConfigurationSetName", "Default")
  end

  test "event destination publishes every event type to the topic after the policy exists" do
    destination = resources_of_type("AWS::SES::ConfigurationSetEventDestination").values.sole
    event_destination = destination.dig("Properties", "EventDestination")

    assert_equal EVENT_TYPES.sort, event_destination["MatchingEventTypes"].sort
    assert_equal true, event_destination["Enabled"]
    assert_equal({ "Ref" => "Topic" }, event_destination.dig("SnsDestination", "TopicARN"))
    assert_equal "TopicPolicy", destination["DependsOn"]
  end

  test "topic policy only lets SES publish for this account" do
    statement = resources_of_type("AWS::SNS::TopicPolicy").values.sole.dig("Properties", "PolicyDocument", "Statement").sole

    assert_equal "ses.amazonaws.com", statement.dig("Principal", "Service")
    assert_equal "sns:Publish", statement["Action"]
    assert_equal({ "Ref" => "AWS::AccountId" }, statement.dig("Condition", "StringEquals", "AWS:SourceAccount"))
    assert statement.dig("Condition", "StringEquals", "AWS:SourceArn").present?
  end

  test "subscription posts to the webhook over https" do
    subscription = resources_of_type("AWS::SNS::Subscription").values.sole["Properties"]

    assert_equal "https", subscription["Protocol"]
    assert_equal({ "Ref" => "WebhookUrl" }, subscription["Endpoint"])
  end

  test "subscription keeps retrying for close to the hour SNS allows" do
    policy = resources_of_type("AWS::SNS::Subscription").values.sole.dig("Properties", "DeliveryPolicy", "healthyRetryPolicy")

    assert_equal Source::SNS_RETRY_POLICY, policy

    # No backoff phase, so the retry time is exactly the two fixed phases.
    assert_equal policy["numRetries"], policy["numNoDelayRetries"] + policy["numMinDelayRetries"] + policy["numMaxDelayRetries"]
    retry_seconds = policy["numMinDelayRetries"] * policy["minDelayTarget"] + policy["numMaxDelayRetries"] * policy["maxDelayTarget"]
    assert_operator retry_seconds, :>=, 50.minutes

    # SNS rejects an HTTPS policy whose total retry time exceeds 3,600 seconds,
    # which would fail every Launch Stack. Stay under it even if every retry
    # were counted at the maximum delay.
    assert_operator policy["numRetries"] * policy["maxDelayTarget"], :<=, 3600
  end

  test "template creates no IAM resources" do
    assert_empty template["Resources"].values.map { |r| r["Type"] }.grep(/\AAWS::IAM::/)
  end

  test "configuration set is only created when no existing one is named" do
    config_set = resources_of_type("AWS::SES::ConfigurationSet").values.sole

    assert_equal "CreateConfigSet", config_set["Condition"]
    assert_equal [ { "Ref" => "ExistingConfigurationSetName" }, "" ], template.dig("Conditions", "CreateConfigSet", "Fn::Equals")
  end

  test "committed template matches the published digest" do
    assert_equal PUBLISHED_TEMPLATE_SHA256, Digest::SHA256.hexdigest(File.read(TEMPLATE_PATH)),
      "Template changed: publish it under a new key and update PUBLISHED_TEMPLATE_SHA256"
  end

  # A missing or swapped object is a defect (the Launch Stack link would open a
  # broken console page), so only a network failure skips; any HTTP status
  # other than 2xx fails.
  test "published template at the default URL has the pinned digest" do
    skip "network check runs only in CI" unless ENV["CI"]

    url = Rails.configuration.x.cloudformation_template_url
    response = fetch(url)
    skip "published template unreachable" if response.nil?

    assert_kind_of Net::HTTPSuccess, response, "Published template returned HTTP #{response.code} at #{url}"
    assert_equal PUBLISHED_TEMPLATE_SHA256, Digest::SHA256.hexdigest(response.body)
  end

  test "names Sessy generates satisfy the template's parameter constraints" do
    long = accounts(:instance).sources.create!(name: "a" * 200, aws_region: "us-east-1")
    short = accounts(:instance).sources.create!(name: "日本語", aws_region: "us-east-1")

    [ long, short ].each do |source|
      url = source.launch_stack_url(webhook_url: "https://app.example.com/webhooks/#{source.token}")
      query = Rack::Utils.parse_query(url.split("review?").last)

      template["Parameters"].each do |name, parameter|
        value = query.fetch("param_#{name}")
        assert_match Regexp.new(parameter["AllowedPattern"]), value, "#{name}=#{value.inspect} violates the template"
      end
    end
  end

  test "template URL defaults to the Sessy bucket and honors the environment" do
    assert_match %r{\Ahttps://.+\.s3\..*amazonaws\.com/v\d+/sessy-ses\.yml\z}, Rails.configuration.x.cloudformation_template_url
  end

  private

  def template
    # Long-form intrinsics (Ref:, Fn::If:) keep the template plain YAML, so
    # safe_load works here and the file also loads as JSON-compatible data.
    @template ||= YAML.safe_load(File.read(TEMPLATE_PATH))
  end

  def resources_of_type(type)
    template["Resources"].select { |_, resource| resource["Type"] == type }
  end

  def fetch(url)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri)
    end
  rescue SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError
    nil
  end
end
