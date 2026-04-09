class EvangelismMeetingsController < ApplicationController
  before_action :require_admin!
  before_action :set_evangelism_meeting, only: [:edit, :update]
  before_action :load_regions, only: [:edit, :update]

  def index
    @evangelism_meetings = EvangelismMeeting.includes(:region).display_sorted
  end

  def edit
  end

  def update
    if @evangelism_meeting.update(evangelism_meeting_params)
      redirect_to evangelism_meetings_path, notice: "伝道会を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_evangelism_meeting
    @evangelism_meeting = EvangelismMeeting.find(params[:id])
  end

  def load_regions
    @regions = Region.order(:name)
  end

  def evangelism_meeting_params
    params.require(:evangelism_meeting).permit(:name, :color_code, :region_id, :display_order, :active)
  end
end
