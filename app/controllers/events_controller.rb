class EventsController < ApplicationController
  before_action :require_admin!
  before_action :set_event, only: [:edit, :update]

  def index
    @events = Event.recent_first
  end

  def edit
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
