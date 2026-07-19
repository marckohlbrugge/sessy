class SourcesController < ApplicationController
  before_action :set_source, only: %i[show edit update destroy]

  def index
    @sources = Current.account.sources.alphabetically
    @source_stats = Source.overview_stats(@sources)
  end

  def show
    overview_range = 29.days.ago.beginning_of_day..Time.zone.today.end_of_day
    stats = EmailStats.new(@source.events, overview_range)

    @sent_count = stats.sent_count
    @delivered_count = stats.delivered_count
    @bounce_count = stats.bounce_count
    @complaint_count = stats.complaint_count
    @open_count = stats.open_count
    @click_count = stats.click_count
    @unique_open_count = stats.unique_open_count
    @unique_click_count = stats.unique_click_count

    @bounce_rate = stats.bounce_rate
    @complaint_rate = stats.complaint_rate
    @open_rate = stats.open_rate
    @click_rate = stats.click_rate

    @chart_data = stats.daily_series
    @sent_today_count = @chart_data[:series].find { |s| s[:key] == :sent }[:values].last || 0
    @bounce_breakdown = stats.bounce_breakdown
  end

  def new
    @source = Current.account.sources.new(color: Source.next_available_color)
  end

  def create
    @source = Current.account.sources.new(source_params)

    if @source.save
      redirect_to @source, notice: "Source created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @source.update(source_params)
      redirect_to @source, notice: "Source updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @source.destroy
    redirect_to sources_path, notice: "Source deleted."
  end

  private

  def set_source
    @source = Current.account.sources.find(params[:id])
  end

  def source_params
    params.require(:source).permit(:name, :color, :retention_days)
  end
end
