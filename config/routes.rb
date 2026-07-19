Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Webhook for receiving SNS notifications (per source)
  post "webhooks/:source_token", to: "webhooks#create", as: :webhook

  # MCP server for AI agents. The route answers on any host; self-hosted uses
  # the main host with no extra configuration.
  match "mcp", to: "mcp#handle", via: %i[get post delete], as: :mcp_endpoint

  # When a dedicated API host is configured (hosted: api.sessy.do), it serves
  # nothing but the MCP endpoint and the health check above — everything else
  # bounces to the app host, so sign-in and app pages never answer there.
  constraints Routes::ApiHost do
    match "*path", to: redirect { |_params, request| "https://#{Routes::ApiHost.app_host}#{request.fullpath}" }, via: :all, format: false
    match "/", to: redirect { "https://#{Routes::ApiHost.app_host}" }, via: :all
  end

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
