Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Webhook for receiving SNS notifications (per source)
  post "webhooks/:source_token", to: "webhooks#create", as: :webhook

  # MCP server for AI agents. No host constraint: hosted advertises it on the
  # api subdomain via DNS/proxy config only, self-hosted uses the main host.
  match "mcp", to: "mcp#handle", via: %i[get post delete], as: :mcp_endpoint
  get "docs/mcp", to: "docs#mcp", as: :mcp_docs

  resources :api_keys, only: [ :index, :create, :destroy ]

  # Dashboard
  resources :sources, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    resource :setup, only: [ :show ]
    resources :events, only: [ :index ]
    resources :messages, only: [ :show ]
  end

  root "sources#index"
end
