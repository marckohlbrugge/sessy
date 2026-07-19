class DocsController < ApplicationController
  def mcp
    api_host = Rails.configuration.x.api_host
    @endpoint_url = api_host.present? ? "https://#{api_host}/mcp" : "#{request.base_url}/mcp"
    @tools = McpServer.tools
  end
end
