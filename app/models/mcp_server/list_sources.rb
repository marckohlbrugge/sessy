class McpServer::ListSources < McpServer::BaseTool
  tool_name "list_sources"
  title "List sources"
  description "List this account's email sources with 30-day health stats (sent count, bounce rate, last event). Start here: the other tools take a source_id from these results."
  input_schema(properties: {}, required: [], additionalProperties: false)

  def self.perform(account:, app_base_url:, **)
    sources = account.sources.alphabetically

    if sources.none?
      return {
        sources: [],
        guidance: "No sources yet. Create one at #{app_base_url}/sources, then point AWS SES at its webhook URL (shown on the source's Setup page) so events start flowing."
      }
    end

    stats = Source.overview_stats(sources)

    {
      sources: sources.map do |source|
        source_stats = stats[source.id]
        {
          id: source.id,
          name: source.name,
          messages_count: source.messages_count,
          sent_30d: source_stats[:sent_30d],
          bounce_rate_30d: source_stats[:bounce_rate]&.round(2),
          last_event_at: source_stats[:last_event_at]&.iso8601
        }
      end
    }
  end
end
