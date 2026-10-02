class SetupsController < ApplicationController
  include SourceScoped

  # The status strip polls this action inside a Turbo Frame; answer those
  # requests with the strip alone instead of rendering the whole page.
  def show
    render partial: "setups/status", locals: { source: @source } if turbo_frame_request?
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
