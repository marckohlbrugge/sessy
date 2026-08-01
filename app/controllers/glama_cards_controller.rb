# Public claim file so Glama can verify connector ownership for the hosted
# remote (api.sessy.do). Email must match the Glama account; see
# https://glama.ai/mcp/schemas/connector.json
class GlamaCardsController < ActionController::API
  def show
    email = ENV["GLAMA_MAINTAINER_EMAIL"].presence
    return head :not_found if email.blank?

    render json: {
      "$schema" => "https://glama.ai/mcp/schemas/connector.json",
      "maintainers" => [ { "email" => email } ]
    }
  end
end
