# One-click account approval, linked from the admin signup notification email.
# The signed token in the URL is the credential: the code is public but
# secret_key_base isn't, so only holders of an emailed link (the operator)
# can reach a valid page. Invalid or expired tokens 404.
class Sessy::Saas::Admin::ApprovalsController < ApplicationController
  allow_unauthenticated_access

  layout "sessy/saas/public"

  before_action :set_account

  def show
  end

  def create
    @account.approve! unless @account.approved?
    redirect_to admin_approval_path(token: params[:token]), notice: "Approved. #{@account.users.first&.email_address} has been emailed."
  end

  private

  def set_account
    @account = Account.find_signed(params[:token], purpose: :admin_approval)
    head :not_found if @account.nil?
  end
end
