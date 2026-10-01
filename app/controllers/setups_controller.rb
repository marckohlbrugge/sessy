class SetupsController < ApplicationController
  include SourceScoped

  def show
  end

  # Only the SES region lives here: SourcesController#update redirects to
  # Overview, which would bounce the user off the page they are setting up.
  def update
    if @source.update(setup_params)
      redirect_to source_setup_path(@source)
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setup_params
    params.require(:source).permit(:aws_region)
  end
end
