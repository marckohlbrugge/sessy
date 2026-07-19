class McpServer::GetMessage < McpServer::BaseTool
  EVENTS_LIMIT = 500

  tool_name "get_message"
  title "Get message"
  description "Fetch one email by its ses_message_id (from search_events results): subject, sender, destinations, SES tags, and the per-recipient event timeline including bounce/complaint diagnostics (first #{EVENTS_LIMIT} events; events_truncated flags the rest — use search_events to page through them)."
  input_schema(
    properties: {
      ses_message_id: { type: "string", description: "SES message id from search_events results" }
    },
    required: [ "ses_message_id" ],
    additionalProperties: false
  )

  def self.perform(account:, ses_message_id:, **)
    message = account_messages(account).find_by(ses_message_id: ses_message_id)

    unless message
      raise ToolError, "No message found for that ses_message_id. It may never have existed, or the source's retention policy may have deleted it."
    end

    payload = {
      message: {
        ses_message_id: message.ses_message_id,
        subject: message.subject,
        from: message.source_email,
        destinations: message.destination_emails,
        tags: message.tags,
        source: { id: message.source_id, name: message.source&.name },
        sent_at: message.sent_at&.iso8601
      },
      # Capped: a bulk send accumulates one event per recipient per type under
      # one ses_message_id, and an uncapped timeline could dwarf the response
      # budget MCP clients give a tool result.
      events: message.events.order(event_at: :asc, id: :asc).limit(EVENTS_LIMIT).map do |event|
        {
          event_type: event.event_type,
          bounce_type: event.bounce_type,
          recipient_email: event.recipient_email,
          event_at: event.event_at.iso8601,
          details: truncate_strings(event.event_data)
        }.compact
      end
    }
    payload[:events_truncated] = true if message.events_count > EVENTS_LIMIT
    payload
  end
end
