class DocsController < ApplicationController
  def mcp
    @tools = McpServer.tools
  end
end
