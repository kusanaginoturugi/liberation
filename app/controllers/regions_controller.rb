class RegionsController < ApplicationController
  before_action :require_admin!
  before_action :set_region, only: [ :edit, :update ]

  def index
    @regions = Region.left_joins(:evangelism_meetings)
                     .select("regions.*, COUNT(evangelism_meetings.id) AS evangelism_meetings_count")
                     .group("regions.id")
                     .order(:name)
  end

  def edit
  end

  def update
    if @region.update(region_params)
      redirect_to regions_path, notice: "聖院を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_region
    @region = Region.find(params[:id])
  end

  def region_params
    params.require(:region).permit(:name)
  end
end
