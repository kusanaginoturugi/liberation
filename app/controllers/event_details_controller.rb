class EventDetailsController < ApplicationController
  before_action :require_admin!
  before_action :set_event
  before_action :ensure_event_details!
  before_action :set_event_detail, only: [ :edit, :update ]

  def index
    @event_details = @event.event_details.includes(:region).references(:region).order("regions.name")
  end

  def edit
  end

  def update
    if @event_detail.update(event_detail_params)
      redirect_to event_event_details_path(@event), notice: "聖院別設定を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_event_detail
    @event_detail = @event.event_details.find(params[:id])
  end

  def ensure_event_details!
    Region.order(:id).find_each do |region|
      EventDetail.find_or_create_by!(event: @event, region: region) do |detail|
        detail.total_serial_count = EventDetail::DEFAULT_TOTAL_SERIAL_COUNT
      end
    end
  end

  def event_detail_params
    params.require(:event_detail).permit(:total_serial_count)
  end
end
