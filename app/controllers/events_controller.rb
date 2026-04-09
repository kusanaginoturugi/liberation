class EventsController < ApplicationController
  before_action :require_admin!
  before_action :set_event, only: [:edit, :update]

  def index
    @events = Event.recent_first
  end

  def new
    @event = Event.new
  end

  def edit
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      Region.order(:id).find_each do |region|
        EventDetail.find_or_create_by!(event: @event, region: region) do |detail|
          detail.total_serial_count = EventDetail::DEFAULT_TOTAL_SERIAL_COUNT
        end
      end

      redirect_to events_path, notice: "超抜式を追加しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @event.update(event_params)
      redirect_to events_path, notice: "超抜式を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:name)
  end
end
