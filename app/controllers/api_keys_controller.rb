class ApiKeysController < ApplicationController
  def index
    @api_keys = Current.account.api_keys.order(created_at: :desc)
    @api_key = ApiKey.new
  end

  def create
    @api_key = Current.account.api_keys.new(api_key_params)

    if @api_key.save
      flash[:api_key_token] = @api_key.token
      redirect_to api_keys_path
    else
      @api_keys = Current.account.api_keys.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Current.account.api_keys.find(params[:id]).destroy
    redirect_to api_keys_path, notice: "API key revoked."
  end

  private

  def api_key_params
    params.require(:api_key).permit(:name)
  end
end
