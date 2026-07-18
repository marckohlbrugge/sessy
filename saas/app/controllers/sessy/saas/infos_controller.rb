class Sessy::Saas::InfosController < ApplicationController
  # Public diagnostic: engine version + environment, no tenant data.
  allow_unauthenticated_access
  allow_pending_access

  def show
  end
end
