# Public, unauthenticated metadata for MCP directory scanners that cannot
# complete tools/list against a bearer-gated /mcp endpoint (e.g. Smithery).
class McpServerCardsController < ActionController::API
  def show
    render json: McpServer.server_card
  end
end
