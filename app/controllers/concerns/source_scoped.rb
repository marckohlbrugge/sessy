module SourceScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_source
  end

  private

  def set_source
    @source = Current.account.sources.find(params[:source_id])
  end
end
