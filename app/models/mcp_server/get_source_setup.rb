class McpServer::GetSourceSetup < McpServer::BaseTool
  tool_name "get_source_setup"
  title "Get source setup"
  description "Fetch one source's settings and the AWS SES wiring details for it: webhook URL for the SNS subscription, suggested configuration set and topic names, and the remaining setup steps. Use this to finish or verify SES setup for an existing source."
  input_schema(
    properties: {
      source_id: { type: "integer", description: "Source id from list_sources" }
    },
    required: [ "source_id" ],
    additionalProperties: false
  )
  output_schema(
    properties: {
      source: SOURCE_SCHEMA,
      setup: SETUP_SCHEMA
    },
    required: %w[source setup],
    additionalProperties: false
  )

  def self.perform(account:, app_base_url:, source_id:, **)
    source = find_source!(account, source_id)

    {
      source: source_payload(source, app_base_url),
      setup: setup_payload(source, app_base_url)
    }
  end
end
