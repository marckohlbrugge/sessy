class McpServer::UpdateSource < McpServer::BaseTool
  tool_name "update_source"
  title "Update source"
  description "Rename a source or change its badge color. Omitted fields are left unchanged. Retention and deletion are deliberately not available here — use the web UI."
  # Same arguments always converge on the same row state, so retries are safe.
  annotations(read_only_hint: false, idempotent_hint: true, destructive_hint: false, open_world_hint: false)
  input_schema(
    properties: {
      source_id: { type: "integer", description: "Source id from list_sources" },
      name: { type: "string", minLength: 1, description: "New display name" },
      color: { type: "string", enum: Source::Colors::ALL, description: "New badge color" }
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

  def self.perform(account:, app_base_url:, source_id:, name: nil, color: nil, **)
    source = find_source!(account, source_id)
    changes = { name: name&.strip, color: color }.compact

    if changes.empty?
      raise ToolError, "Nothing to update. Pass a new name and/or color."
    end

    unless source.update(changes)
      raise ToolError, "Could not update source: #{source.errors.full_messages.to_sentence}."
    end

    {
      source: source_payload(source, app_base_url),
      setup: setup_payload(source, app_base_url)
    }
  end
end
