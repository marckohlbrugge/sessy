class SetupsController < ApplicationController
  include SourceScoped

  # The status line polls this action inside a Turbo Frame; answer those
  # requests with the line alone instead of rendering the whole page.
  #
  # One step is rendered per request: the current one, or an earlier one
  # read-only when ?step= asks for it. A later step is clamped back to the
  # current one so the URL cannot skip ahead.
  def show
    if turbo_frame_request?
      render partial: "setups/status", locals: { source: @source }
    else
      @step = shown_step
    end
  end

  # Only the SES region lives here: SourcesController#update redirects to
  # Overview, which would bounce the user off the page they are setting up.
  # The picker sits inside the "More options" disclosure, so the render that
  # follows keeps it open: closing it under the user would also drop focus
  # from the select that data-turbo-permanent just preserved.
  def update
    if @source.update(setup_params)
      redirect_to source_setup_path(@source), flash: { setup_more_open: true }
    else
      @step = helpers.setup_current_step(@source)
      flash.now[:setup_more_open] = true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setup_params
    params.require(:source).permit(:aws_region)
  end

  def shown_step
    current = helpers.setup_current_step(@source)
    params[:step].present? ? params[:step].to_i.clamp(1, current) : current
  end
end
