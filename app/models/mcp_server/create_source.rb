class McpServer::CreateSource < McpServer::BaseTool
  tool_name "create_source"
  title "Create source"
  description "Create a new email source (one per app or mail stream) and return the AWS SES wiring details for it: webhook URL for the SNS subscription, suggested configuration set and topic names, and the remaining setup steps. Retention is configured in the web UI."
  # Not idempotent: calling twice with the same name creates two sources.
  annotations(read_only_hint: false, idempotent_hint: false, destructive_hint: false, open_world_hint: false)
  input_schema(
    properties: {
      name: { type: "string", minLength: 1, description: "Display name, e.g. the app or mail stream it tracks" },
      color: { type: "string", enum: Source::Colors::ALL, description: "Badge color in the web UI; defaults to the least-used color" }
    },
    required: [ "name" ],
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

  def self.perform(account:, app_base_url:, name:, color: nil, **)
    source = account.sources.new(name: name.strip, color: color.presence || account.sources.next_available_color)

    unless source.save
      raise ToolError, "Could not create source: #{source.errors.full_messages.to_sentence}."
    end

    {
      source: source_payload(source, app_base_url),
      setup: setup_payload(source, app_base_url)
    }
  end
end
