# The CloudFormation quick-create link on the Setup page (KTD3, KTD4, KTD5).
# The region is interpolated into the console hostname, so the inclusion
# validation and the nil return for an unknown stored value are security
# controls, not only UX.
module Source::LaunchStack
  extend ActiveSupport::Concern

  # SES commercial regions, in the order of the SES endpoints table.
  SES_REGIONS = {
    "us-east-2" => "US East (Ohio)",
    "us-east-1" => "US East (N. Virginia)",
    "us-west-1" => "US West (N. California)",
    "us-west-2" => "US West (Oregon)",
    "af-south-1" => "Africa (Cape Town)",
    "ap-south-2" => "Asia Pacific (Hyderabad)",
    "ap-southeast-3" => "Asia Pacific (Jakarta)",
    "ap-southeast-5" => "Asia Pacific (Malaysia)",
    "ap-south-1" => "Asia Pacific (Mumbai)",
    "ap-northeast-3" => "Asia Pacific (Osaka)",
    "ap-northeast-2" => "Asia Pacific (Seoul)",
    "ap-southeast-1" => "Asia Pacific (Singapore)",
    "ap-southeast-2" => "Asia Pacific (Sydney)",
    "ap-northeast-1" => "Asia Pacific (Tokyo)",
    "ca-central-1" => "Canada (Central)",
    "ca-west-1" => "Canada West (Calgary)",
    "eu-central-1" => "Europe (Frankfurt)",
    "eu-west-1" => "Europe (Ireland)",
    "eu-west-2" => "Europe (London)",
    "eu-south-1" => "Europe (Milan)",
    "eu-west-3" => "Europe (Paris)",
    "eu-north-1" => "Europe (Stockholm)",
    "eu-central-2" => "Europe (Zurich)",
    "il-central-1" => "Israel (Tel Aviv)",
    "me-south-1" => "Middle East (Bahrain)",
    "me-central-1" => "Middle East (UAE)",
    "sa-east-1" => "South America (Sao Paulo)"
  }.freeze

  STACK_NAME_MAX_LENGTH = 128

  included do
    before_validation { self.aws_region = aws_region.presence }
    validates :aws_region, inclusion: { in: SES_REGIONS.keys }, allow_nil: true
  end

  def aws_region_known?
    SES_REGIONS.key?(aws_region)
  end

  # Quick-create URL for the region's CloudFormation console, or nil until a
  # known region is chosen. Every value is percent-encoded individually.
  def launch_stack_url(webhook_url:)
    return unless aws_region_known?

    query = {
      templateURL: Rails.configuration.x.cloudformation_template_url,
      stackName: stack_name,
      param_WebhookUrl: webhook_url,
      param_ConfigurationSetName: config_set_name,
      param_TopicName: sns_topic_name,
      param_ExistingConfigurationSetName: ""
    }.map { |key, value| "#{key}=#{ERB::Util.url_encode(value)}" }.join("&")

    "https://#{aws_region}.console.aws.amazon.com/cloudformation/home?region=#{aws_region}#/stacks/create/review?#{query}"
  end

  # sessy-<slug>-<id>: the id avoids AlreadyExists when two sources share a
  # name; CloudFormation wants [a-zA-Z][-a-zA-Z0-9]* and at most 128 chars.
  def stack_name
    suffix = "-#{id}"
    slug = name.parameterize.tr("_", "-")
    return "sessy-source#{suffix}" if slug.blank?

    "sessy-#{slug}"[0, STACK_NAME_MAX_LENGTH - suffix.length].sub(/-+\z/, "") + suffix
  end
end
