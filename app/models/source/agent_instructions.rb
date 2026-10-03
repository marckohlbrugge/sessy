# Markdown prompts the Setup page offers to copy for an AI coding agent, one
# per active step, with the source's real values filled in. The webhook and
# Launch Stack URLs depend on the request host, so the caller passes them.
# Plain text only: nothing here is rendered as HTML, and Tailwind never scans
# this file.
class Source::AgentInstructions
  def initialize(source, webhook_url:, launch_stack_url:)
    @source = source
    @webhook_url = webhook_url
    @launch_stack_url = launch_stack_url
  end

  def connect
    <<~MARKDOWN
      # Connect AWS SES to Sessy

      Sessy is an email observability tool: it receives SES events (sends, deliveries, bounces, complaints, opens, clicks) through an SNS webhook and shows them per recipient.

      ## Goal

      Make SES publish every event for the configuration set `#{config_set_name}` to this webhook URL over HTTPS:

          #{webhook_url}

      #{region_guidance}

      ## Fastest path: one CloudFormation stack

      Open this URL in a browser (it needs the AWS console session, so a human may have to do this part), review the parameters and click "Create stack". The stack is named `#{stack_name}` and creates no IAM resources:

          #{launch_stack_url}

      If a configuration set is already in use for sending, enter its name as `ExistingConfigurationSetName` on the review page and the stack attaches to it instead of creating `#{config_set_name}`.

      ## CLI path

      Use these if the console is not an option. Replace `<account-id>` with the account id from the `create-topic` output (the topic ARN is `arn:aws:sns:#{region_or_placeholder}:<account-id>:#{sns_topic_name}`).

      ```sh
      aws sesv2 create-configuration-set \\
        --configuration-set-name "#{config_set_name}"#{region_flag}

      aws sns create-topic \\
        --name "#{sns_topic_name}"#{region_flag}

      aws sns subscribe \\
        --topic-arn "arn:aws:sns:#{region_or_placeholder}:<account-id>:#{sns_topic_name}" \\
        --protocol https \\
        --notification-endpoint "#{webhook_url}"#{region_flag}

      aws sesv2 create-configuration-set-event-destination \\
        --configuration-set-name "#{config_set_name}" \\
        --event-destination-name "#{sns_topic_name}" \\
        --event-destination '{
          "Enabled": true,
          "MatchingEventTypes": ["SEND","DELIVERY","DELIVERY_DELAY","BOUNCE","COMPLAINT","REJECT","OPEN","CLICK","RENDERING_FAILURE","SUBSCRIPTION"],
          "SnsDestination": {"TopicArn": "arn:aws:sns:#{region_or_placeholder}:<account-id>:#{sns_topic_name}"}
        }'#{region_flag}
      ```

      Leave raw message delivery off on the subscription; Sessy confirms it automatically.

      ## Success

      The Setup page for this source shows SNS connected and moves on to sending a test email. Nothing else is needed on the Sessy side: no AWS credentials are shared with Sessy.

      Sessy also exposes an MCP server whose `get_source_setup` tool returns these same values.
    MARKDOWN
  end

  def send_test_email
    <<~MARKDOWN
      # Send a test email through the Sessy configuration set

      SNS is connected. Sessy now needs one email sent through the SES configuration set `#{config_set_name}` so the first event arrives.

      ## Attach the configuration set

      Pick whichever matches how the app sends email.

      With the AWS SDK (aws-sdk-sesv2), pass it on every send:

      ```ruby
      ses.send_email(
        from_email_address: "you@example.com",
        destination: { to_addresses: ["you@example.com"] },
        content: { simple: { subject: { data: "Sessy test" }, body: { text: { data: "Hello from Sessy" } } } },
        configuration_set_name: "#{config_set_name}"
      )
      ```

      With Action Mailer (aws-actionmailer-ses), set the header once:

      ```ruby
      class ApplicationMailer < ActionMailer::Base
        default "X-SES-CONFIGURATION-SET" => "#{config_set_name}"
      end
      ```

      Or make it the default for everything a verified identity sends, with no code change:

      ```sh
      aws sesv2 put-email-identity-configuration-set-attributes \\
        --email-identity example.com \\
        --configuration-set-name "#{config_set_name}"#{region_flag}
      ```

      #{region_guidance}

      ## Send one email

      Send a single test email to yourself through the configured path.

      ## Success

      The Setup page for this source shows the first event within seconds and the source's Activity page lists the delivery. Sessy's MCP server (`get_source_setup`, `search_events`) can confirm the same.
    MARKDOWN
  end

  private

  attr_reader :source, :webhook_url, :launch_stack_url

  delegate :config_set_name, :sns_topic_name, :stack_name, to: :source

  # Commands always carry the region flag: when none is recorded the agent
  # swaps one placeholder instead of guessing where the flag goes.
  def region_flag
    " \\\n  --region #{region_or_placeholder}"
  end

  def region_or_placeholder
    source.aws_region_known? ? source.aws_region : "<region-code>"
  end

  def region_guidance
    if source.aws_region_known?
      "Region: `#{source.aws_region}` (#{source.aws_region_name})."
    else
      "Region: replace `<region-code>` with the region your app sends SES email from (the SES client's `region:` or `AWS_REGION`, or the `email-smtp.*.amazonaws.com` SMTP host)."
    end
  end
end
