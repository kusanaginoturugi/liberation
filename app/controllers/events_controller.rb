class EventsController < ApplicationController
  before_action :require_admin!
  before_action :set_event, only: [ :edit, :update, :destroy ]

  def index
    @events = Event.recent_first
  end

  def new
    @event = Event.new
    @total_serial_count_input = default_total_serial_count
  end

  def edit
    @total_serial_count_input = current_total_serial_count_for(@event)
  end

  def create
    @event = Event.new(event_params)
    @total_serial_count_input = total_serial_count_input

    unless valid_total_serial_count_input?
      @event.errors.add(:base, "修霊合計数は1以上の半角数字で入力してください")
      render :new, status: :unprocessable_content
      return
    end

    ActiveRecord::Base.transaction do
      if @event.save
        Region.order(:id).find_each do |region|
          EventDetail.find_or_create_by!(event: @event, region: region) do |detail|
            detail.total_serial_count = default_total_serial_count
          end
        end

        update_primary_event_detail!(@event, @total_serial_count_input.to_i) if single_region_mode?
        close_other_events!(@event) unless @event.closed?
        redirect_to events_path, notice: "超抜式を追加しました"
      else
        raise ActiveRecord::Rollback
      end
    end

    unless performed?
      render :new, status: :unprocessable_content
    end
  end

  def update
    @total_serial_count_input = total_serial_count_input

    unless valid_total_serial_count_input?
      @event.assign_attributes(event_params)
      @event.errors.add(:base, "修霊合計数は1以上の半角数字で入力してください")
      render :edit, status: :unprocessable_content
      return
    end

    ActiveRecord::Base.transaction do
      if @event.update(event_params)
        update_primary_event_detail!(@event, @total_serial_count_input.to_i) if single_region_mode?
        close_other_events!(@event) unless @event.closed?
        redirect_to events_path, notice: "超抜式を更新しました"
      else
        raise ActiveRecord::Rollback
      end
    end

    unless performed?
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    unless deletable_event?(@event)
      redirect_to edit_event_path(@event), alert: "超抜報告が紐づいているため削除できません"
      return
    end

    was_open = !@event.closed?
    @event.destroy!
    open_fallback_event! if was_open
    redirect_to events_path, notice: "超抜式を削除しました"
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:name, :closed)
  end

  def total_serial_count_input
    params.dig(:event, :total_serial_count).presence || @total_serial_count_input
  end

  def valid_total_serial_count_input?
    return true unless single_region_mode?

    value = total_serial_count_input.to_s
    value.match?(/\A[1-9][0-9]*\z/)
  end

  def current_total_serial_count_for(event)
    return default_total_serial_count unless single_region_mode?

    event.event_details.find_by(region_id: primary_region_id)&.total_serial_count || default_total_serial_count
  end

  def update_primary_event_detail!(event, total_serial_count)
    detail = event.event_details.find_or_initialize_by(region_id: primary_region_id)
    detail.total_serial_count = total_serial_count
    detail.save!
  end

  def default_total_serial_count
    EventDetail::DEFAULT_TOTAL_SERIAL_COUNT
  end

  def close_other_events!(event)
    Event.where.not(id: event.id).update_all(closed: true)
  end

  def deletable_event?(event)
    !event.chobatsu_reports.exists?
  end

  def open_fallback_event!
    fallback_event = Event.recent_first.first
    return if fallback_event.blank? || !fallback_event.closed?

    fallback_event.update_column(:closed, false)
  end
end
