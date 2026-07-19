require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  INSTANCE_TOKEN = "sessy_instance_test_key"
  PROTOCOL_VERSION = "2025-06-18"

  test "initialize handshake succeeds with a valid key" do
    rpc "initialize", { protocolVersion: PROTOCOL_VERSION, capabilities: {}, clientInfo: { name: "test", version: "1.0" } }

    assert_response :success
    result = rpc_result
    assert_equal "sessy", result.dig("serverInfo", "name")
    assert result["instructions"].present?
  end

  test "notifications return 202" do
    rpc "notifications/initialized", {}, id: nil

    assert_response :accepted
  end

  test "missing, unknown, and revoked tokens return byte-identical 401s" do
    revoked = accounts(:instance).api_keys.create!(name: "Doomed")
    revoked_token = revoked.token
    revoked.destroy

    bodies = [ nil, "sessy_totally_wrong", revoked_token ].map do |token|
      call_tool "list_sources", token: token
      assert_response :unauthorized
      assert_equal 'Bearer realm="Sessy MCP"', response.headers["WWW-Authenticate"]
      response.body
    end

    assert_equal 1, bodies.uniq.size
    assert_no_match(/sessy_totally_wrong/, bodies[1])
    assert_no_match(/#{Regexp.escape(revoked_token)}/, bodies[2])
  end

  test "a working key stops working the request after it is revoked" do
    api_key = accounts(:instance).api_keys.create!(name: "Short-lived")
    token = api_key.token

    call_tool "list_sources", token: token
    assert_response :success

    api_key.destroy
    call_tool "list_sources", token: token
    assert_response :unauthorized
  end

  test "a key of an unapproved account gets a 403 naming the pending state" do
    account = Account.create!(name: "Pending Co")
    api_key = account.api_keys.create!(name: "Waiting")

    call_tool "list_sources", token: api_key.token
    assert_response :forbidden
    assert_match(/pending approval/i, response.body)
    assert_nil api_key.reload.last_used_at

    account.approve!
    call_tool "list_sources", token: api_key.token
    assert_response :success
    assert_not_nil api_key.reload.last_used_at
  end

  test "tools/list shows tools with titles and readOnlyHint" do
    rpc "tools/list"

    assert_response :success
    tools = rpc_result["tools"]
    list_sources = tools.find { |tool| tool["name"] == "list_sources" }

    assert list_sources.present?
    assert_equal "List sources", list_sources["title"]
    assert_equal true, list_sources.dig("annotations", "readOnlyHint")
    assert_equal false, list_sources.dig("annotations", "destructiveHint")
    tools.each do |tool|
      assert_equal false, tool.dig("inputSchema", "additionalProperties"), "#{tool["name"]} schema must forbid unknown params"
    end
  end

  test "list_sources returns only the key's account's sources" do
    other_account, _other_key = populated_other_account

    call_tool "list_sources"

    assert_response :success
    names = tool_payload["sources"].map { |source| source["name"] }
    assert_includes names, sources(:betalist).name
    assert_not names.intersect?(other_account.sources.pluck(:name)), "other account's sources leaked"

    betalist_row = tool_payload["sources"].find { |source| source["name"] == sources(:betalist).name }
    assert_equal 2, betalist_row["sent_30d"], "welcome_send + digest_send fixtures"
    assert_equal 0.0, betalist_row["bounce_rate_30d"], "sends but no bounces is a zero rate, not nil"
    assert_not_nil betalist_row["last_event_at"]
  end

  test "another account's key sees only its own sources" do
    other_account, other_token = populated_other_account

    call_tool "list_sources", token: other_token

    assert_response :success
    names = tool_payload["sources"].map { |source| source["name"] }
    assert_equal other_account.sources.pluck(:name).sort, names.sort
  end

  test "list_sources guides setup when the account has no sources" do
    account = Account.create!(name: "Fresh", approved_at: Time.current)
    api_key = account.api_keys.create!(name: "New agent")

    call_tool "list_sources", token: api_key.token

    assert_response :success
    assert_equal [], tool_payload["sources"]
    assert_match(/create one/i, tool_payload["guidance"])
  end

  test "tool responses mirror structured content as pretty-printed text" do
    call_tool "list_sources"

    assert_response :success
    result = rpc_result
    assert_equal tool_payload, JSON.parse(result["content"].first["text"])
    assert_equal "text", result["content"].first["type"]
  end

  test "browser GET redirects to the docs page on the app host" do
    get mcp_endpoint_path, headers: { "Accept" => "text/html", "Authorization" => "Bearer #{INSTANCE_TOKEN}" }

    assert_response :found
    assert_equal "http://www.example.com/docs/mcp", response.headers["Location"]
  end

  test "with HTTP Basic configured, /mcp works with a bearer key alone while /api_keys demands basic auth" do
    with_env("HTTP_AUTH_USERNAME" => "admin", "HTTP_AUTH_PASSWORD" => "secret") do
      get api_keys_path
      assert_response :unauthorized unless Sessy.saas?

      call_tool "list_sources"
      assert_response :success
    end
  end

  test "per-key and per-IP rate limits return 429 with Retry-After" do
    with_rate_limit_counters do
      McpController::KEY_RATE_LIMIT.times do
        call_tool "list_sources"
        assert_response :success
      end
      call_tool "list_sources"
      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]

      McpController::INVALID_KEY_RATE_LIMIT.times do
        call_tool "list_sources", token: "sessy_wrong"
        assert_response :unauthorized
      end
      call_tool "list_sources", token: "sessy_wrong"
      assert_response :too_many_requests
    end
  end

  test "unexpected tool exceptions return a generic error without exception text" do
    original = McpServer::ListSources.method(:perform)
    McpServer::ListSources.define_singleton_method(:perform) { |**| raise "secret internal detail" }

    call_tool "list_sources"

    assert_response :success
    assert_equal true, rpc_result["isError"]
    assert_no_match(/secret internal detail/, response.body)
    assert_match(/internal error/i, rpc_result["content"].first["text"])
  ensure
    McpServer::ListSources.define_singleton_method(:perform, original)
  end

  test "search_events finds a bounce and get_message shows its diagnostics without raw_payload" do
    data = seed_instance_data

    call_tool "search_events", { event_types: [ "bounce" ], query: "alice" }
    assert_response :success
    row = tool_payload["events"].sole
    assert_equal "bounce", row["event_type"]
    assert_equal "Permanent", row["bounce_type"]
    assert_equal data[:reset_message].ses_message_id, row["ses_message_id"]

    call_tool "get_message", { ses_message_id: row["ses_message_id"] }
    assert_response :success
    payload = tool_payload
    assert_equal "Password reset", payload.dig("message", "subject")
    bounce_event = payload["events"].find { |event| event["event_type"] == "bounce" }
    assert_equal "Permanent", bounce_event["bounce_type"]
    assert_match(/smtp; 550/, bounce_event.dig("details", "bouncedRecipients").first["diagnosticCode"])
    assert_no_match(/raw_payload_secret/, response.body)
  end

  test "long diagnostic strings are truncated" do
    seed_instance_data(diagnostic: "x" * 2_000)

    call_tool "search_events", { event_types: [ "bounce" ] }
    call_tool "get_message", { ses_message_id: tool_payload["events"].first["ses_message_id"] }

    bounce_event = tool_payload["events"].find { |event| event["event_type"] == "bounce" }
    assert_operator bounce_event.dig("details", "bouncedRecipients").first["diagnosticCode"].length, :<=, 500
  end

  test "tools are disjoint across populated accounts" do
    seed_instance_data
    other_account, other_token = populated_other_account

    call_tool "search_events", { date_range: "all_time" }
    assert_response :success
    assert tool_payload["events"].any?
    assert_empty tool_payload["events"].select { |row| row["recipient_email"] == "intruder@example.com" }

    call_tool "search_events", { date_range: "all_time" }, token: other_token
    rows = tool_payload["events"]
    assert rows.any?
    assert rows.all? { |row| row["recipient_email"] == "intruder@example.com" }
    assert_includes rows.map { |row| row["event_type"] }, "send"

    call_tool "email_stats", { date_range: "all_time" }, token: other_token
    assert_equal 1, tool_payload.dig("counts", "sent")
  end

  test "search_events scopes by source and rejects another account's source_id" do
    data = seed_instance_data
    other_account, _token = populated_other_account
    other_source_id = other_account.sources.first.id

    call_tool "search_events", { source_id: data[:source].id, date_range: "all_time" }
    assert_response :success
    assert tool_payload["events"].any?
    assert(tool_payload["events"].all? { |row| [ "Password reset", "Newsletter" ].include?(row["subject"]) })

    call_tool "search_events", { source_id: other_source_id }
    assert_equal true, rpc_result["isError"]
    assert_match(/unknown source_id/i, rpc_result["content"].first["text"])
  end

  test "search_events matches subjects and recipients and honors the bounce-subtype OR logic" do
    seed_instance_data

    call_tool "search_events", { query: "Password reset", date_range: "all_time" }
    assert tool_payload["events"].any?
    assert(tool_payload["events"].all? { |row| row["subject"] == "Password reset" })

    call_tool "search_events", { event_types: [ "send", "bounce" ], bounce_types: [ "permanent" ], date_range: "all_time" }
    types = tool_payload["events"].map { |row| [ row["event_type"], row["bounce_type"] ] }
    assert_includes types, [ "send", nil ]
    assert_includes types, [ "bounce", "Permanent" ]
    assert_not types.any? { |type, subtype| type == "bounce" && subtype != "Permanent" }
  end

  test "empty results echo the applied window and suggest all_time" do
    source = accounts(:instance).sources.create!(name: "Stale")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Old news", sent_at: 35.days.ago)
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Delivery",
      event_at: 35.days.ago, recipient_email: "old@example.com")

    call_tool "search_events", { query: "Old news" }

    assert_response :success
    assert_empty tool_payload["events"]
    assert_equal "last_30_days", tool_payload.dig("applied_date_range", "preset")
    assert_match(/all_time/, tool_payload["hint"])

    call_tool "search_events", { query: "Old news", date_range: "all_time" }
    assert_equal 1, tool_payload["events"].size
  end

  test "keyset pagination survives equal timestamps and mid-pagination inserts" do
    source = accounts(:instance).sources.create!(name: "Paged")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Paged", sent_at: 1.day.ago)
    moment = 1.day.ago.change(usec: 0)
    5.times do |i|
      message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
        event_at: moment, recipient_email: "page#{i}@example.com")
    end

    call_tool "search_events", { source_id: source.id, limit: 3 }
    first_page = tool_payload["events"].map { |row| row["recipient_email"] }
    assert_equal 3, first_page.size
    assert tool_payload["has_more"]
    cursor = tool_payload["next_cursor"]

    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
      event_at: Time.current, recipient_email: "late-arrival@example.com")

    call_tool "search_events", { source_id: source.id, limit: 3, cursor: cursor }
    second_page = tool_payload["events"].map { |row| row["recipient_email"] }
    assert_equal 2, second_page.size
    assert_empty first_page & second_page, "pages must not overlap"
    assert_not_includes second_page, "late-arrival@example.com"
    assert_equal 5, (first_page + second_page).uniq.size
  end

  test "malformed cursors and unknown enum values return instructive errors, not 500s" do
    call_tool "search_events", { cursor: "not-a-cursor" }
    assert_response :success
    assert_equal true, rpc_result["isError"]
    assert_match(/invalid cursor/i, rpc_result["content"].first["text"])

    call_tool "search_events", { event_types: [ "explosion" ] }
    assert_response :success
    assert_equal true, rpc_result["isError"]
    assert_match(/is not one of/, rpc_result["content"].first["text"])

    call_tool "search_events", { date_range: "custom", from_date: "not-a-date" }
    assert_equal true, rpc_result["isError"]
    assert_match(/invalid from_date/i, rpc_result["content"].first["text"])
  end

  test "get_message not-found is identical for nonexistent and foreign message ids" do
    seed_instance_data
    other_account, _token = populated_other_account
    foreign_id = other_account.sources.first.messages.first.ses_message_id

    call_tool "get_message", { ses_message_id: "does-not-exist" }
    assert_equal true, rpc_result["isError"]
    nonexistent_body = rpc_result["content"].first["text"]
    assert_match(/retention/, nonexistent_body)

    call_tool "get_message", { ses_message_id: foreign_id }
    assert_equal true, rpc_result["isError"]
    assert_equal nonexistent_body, rpc_result["content"].first["text"]
  end

  test "custom ranges with date-only bounds include the end day's events" do
    source = accounts(:instance).sources.create!(name: "Dated")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Midday mail", sent_at: 10.days.ago)
    midday = 10.days.ago.change(hour: 12)
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
      event_at: midday, recipient_email: "noon@example.com")

    call_tool "search_events", { query: "Midday mail", date_range: "custom",
      from_date: 11.days.ago.to_date.iso8601, to_date: midday.to_date.iso8601 }

    assert_response :success
    assert_equal 1, tool_payload["events"].size, "a date-only to_date must cover that entire day"
  end

  test "email_stats rejects daily series over ranges longer than 120 days" do
    call_tool "email_stats", { date_range: "custom", from_date: 200.days.ago.to_date.iso8601,
      to_date: Date.current.iso8601, include_daily_series: true }

    assert_response :success
    assert_equal true, rpc_result["isError"]
    assert_match(/120 days/, rpc_result["content"].first["text"])
  end

  test "get_message caps the timeline and flags truncation" do
    source = accounts(:instance).sources.create!(name: "Bulky")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Campaign", sent_at: 1.day.ago)
    base_time = 1.day.ago
    rows = (McpServer::GetMessage::EVENTS_LIMIT + 1).times.map do |i|
      { message_id: message.id, source_id: source.id, ses_message_id: message.ses_message_id,
        event_type: "Send", event_at: base_time + i.seconds, recipient_email: "r#{i}@example.com",
        created_at: Time.current, updated_at: Time.current }
    end
    Event.insert_all!(rows)
    Message.reset_counters(message.id, :events)

    call_tool "get_message", { ses_message_id: message.ses_message_id }

    assert_response :success
    assert_equal McpServer::GetMessage::EVENTS_LIMIT, tool_payload["events"].size
    assert_equal true, tool_payload["events_truncated"]
  end

  test "email_stats aggregates per source or whole account and matches the stats object" do
    data = seed_instance_data

    call_tool "email_stats", { source_id: data[:source].id, date_range: "all_time", include_daily_series: true }
    assert_response :success
    payload = tool_payload
    assert_equal data[:source].name, payload.dig("scope", "source_name")
    assert_equal 2, payload.dig("counts", "sent")
    assert_equal 1, payload.dig("counts", "bounced")
    assert_equal 50.0, payload.dig("rates_percent", "bounce")
    assert_equal({ "Permanent" => 1 }, payload["bounce_breakdown"])
    assert_equal "all_time", payload.dig("applied_date_range", "preset")
    assert payload["daily_series"].present?

    call_tool "email_stats", { source_id: data[:source].id, date_range: "all_time" }
    assert_nil tool_payload["daily_series"]

    call_tool "email_stats", { date_range: "all_time" }
    assert_operator tool_payload.dig("counts", "sent"), :>=, 2, "account-wide stats include all sources"
  end

  private

  # A source in the instance account with a bounced password-reset email
  # (with SES-style diagnostics) and an old newsletter outside the default
  # 30-day window.
  def seed_instance_data(diagnostic: "smtp; 550 5.1.1 user unknown")
    source = accounts(:instance).sources.create!(name: "MCPApp")

    reset_message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Password reset",
      sent_at: 2.hours.ago, source_email: "auth@mcpapp.example", mail_metadata: { "destination" => [ "alice@example.com" ] })
    reset_message.events.create!(source: source, ses_message_id: reset_message.ses_message_id, event_type: "Send",
      event_at: 2.hours.ago, recipient_email: "alice@example.com")
    reset_message.events.create!(source: source, ses_message_id: reset_message.ses_message_id, event_type: "Bounce",
      event_at: 1.hour.ago, recipient_email: "alice@example.com", bounce_type: "Permanent",
      event_data: { "bounceType" => "Permanent", "bounceSubType" => "General",
                    "bouncedRecipients" => [ { "emailAddress" => "alice@example.com", "diagnosticCode" => diagnostic } ] },
      raw_payload: { "secret" => "raw_payload_secret" })

    newsletter = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Newsletter", sent_at: 40.days.ago)
    newsletter.events.create!(source: source, ses_message_id: newsletter.ses_message_id, event_type: "Send",
      event_at: 40.days.ago, recipient_email: "bob@example.com")

    { source: source, reset_message: reset_message }
  end

  def rpc(method, params = {}, token: INSTANCE_TOKEN, id: 1)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream",
      "MCP-Protocol-Version" => PROTOCOL_VERSION
    }
    headers["Authorization"] = "Bearer #{token}" if token

    body = { jsonrpc: "2.0", method: method, params: params }
    body[:id] = id if id

    post mcp_endpoint_path, params: body.to_json, headers: headers
  end

  def call_tool(name, arguments = {}, token: INSTANCE_TOKEN)
    rpc "tools/call", { name: name, arguments: arguments }, token: token
  end

  def rpc_result
    JSON.parse(response.body).fetch("result") { flunk "JSON-RPC error response: #{response.body}" }
  end

  def tool_payload
    rpc_result.fetch("structuredContent")
  end

  # The second account carries data matching every filter the tools accept —
  # scoping bugs pass trivially against empty fixtures.
  def populated_other_account
    account = Account.create!(name: "Other Co", approved_at: Time.current)
    api_key = account.api_keys.create!(name: "Other agent")
    source = account.sources.create!(name: "OtherApp")
    message = source.messages.create!(ses_message_id: SecureRandom.uuid, subject: "Password reset", sent_at: 1.hour.ago)
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Send",
      event_at: 1.hour.ago, recipient_email: "intruder@example.com")
    message.events.create!(source: source, ses_message_id: message.ses_message_id, event_type: "Bounce",
      event_at: 30.minutes.ago, recipient_email: "intruder@example.com", bounce_type: "Permanent")
    [ account, api_key.token ]
  end

  def with_env(vars)
    originals = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| ENV[key] = value }
  end

  def with_rate_limit_counters
    McpController.rate_limit_store = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    McpController.rate_limit_store = Rails.cache
  end
end
