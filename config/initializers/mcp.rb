MCP.configure do |config|
  # Report without request context: the bearer token travels in the
  # Authorization header, which parameter filtering does not cover.
  config.exception_reporter = ->(exception, _server_context) { Rails.error.report(exception) }

  # Reject unknown params and out-of-enum values before tools run, so agents
  # get an instructive schema error instead of silently-empty results.
  config.validate_tool_call_arguments = true
end
