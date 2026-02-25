Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Webhook for receiving SNS notifications (per source)
  post "webhooks/:source_token", to: "webhooks#create", as: :webhook

  # Dashboard
  resources :sources, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    resource :setup, only: [ :show ]
    resources :events, only: [ :index ]
    resources :messages, only: [ :show ]
  end

  root "sources#index"
end
