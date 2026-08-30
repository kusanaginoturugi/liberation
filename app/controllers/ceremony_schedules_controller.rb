class CeremonySchedulesController < ApplicationController
  allow_unauthenticated_access only: [ :index, :export ]

  before_action :set_ceremony_schedule, only: [ :edit, :update, :destroy ]
  before_action :load_events
  before_action :set_selected_event
  before_action :authorize_ceremony_schedule_edit!, only: [ :edit, :update, :destroy ]
  before_action :load_fellowships, only: [ :new, :create, :edit, :update ]

  def index
    @ceremony_schedules = CeremonySchedule.for_event(@selected_event).chronological
    @allocation_sort_direction = allocation_sort_direction
    @next_allocation_sort_direction = next_allocation_sort_direction
    @allocation_rows = allocation_rows_for(@ceremony_schedules)
  end

  def export
    @ceremony_schedules = CeremonySchedule.for_event(@selected_event).chronological
    @allocation_sort_direction = allocation_sort_direction
    @allocation_rows = allocation_rows_for(@ceremony_schedules)

    render :export, layout: false
  end

  def new
    @ceremony_schedule = CeremonySchedule.new(fellowship: editable_fellowship, event: @selected_event)
  end

  def create
    @ceremony_schedule = CeremonySchedule.new(ceremony_schedule_params)
    @ceremony_schedule.event = @selected_event
    assign_fellowship_for_non_admin

    if authorized_fellowship?(@ceremony_schedule.fellowship) && @ceremony_schedule.save
      redirect_to ceremony_schedules_path(event_id: @selected_event.id), notice: "挙行予定を追加しました"
    else
      @ceremony_schedule.errors.add(:fellowship, "の予定を入力する権限がありません") unless authorized_fellowship?(@ceremony_schedule.fellowship)
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @ceremony_schedule.assign_attributes(ceremony_schedule_params)
    assign_fellowship_for_non_admin

    if authorized_fellowship?(@ceremony_schedule.fellowship) && @ceremony_schedule.save
      redirect_to ceremony_schedules_path(event_id: @ceremony_schedule.event_id), notice: "挙行予定を更新しました"
    else
      @ceremony_schedule.errors.add(:fellowship, "の予定を編集する権限がありません") unless authorized_fellowship?(@ceremony_schedule.fellowship)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @ceremony_schedule.destroy!
    redirect_to ceremony_schedules_path(event_id: @ceremony_schedule.event_id), notice: "挙行予定を削除しました"
  end

  private

  def set_ceremony_schedule
    @ceremony_schedule = CeremonySchedule.find(params[:id])
  end

  def authorize_ceremony_schedule_edit!
    return if current_user&.admin?
    return if @ceremony_schedule.fellowship_id == current_user&.fellowship_id

    redirect_to ceremony_schedules_path, alert: "この伝道会の予定を編集する権限がありません"
  end

  def ceremony_schedule_params
    params.require(:ceremony_schedule).permit(
      :fellowship_id,
      :ceremony_at,
      :place,
      :assistant_count,
      :spirit_count,
      :minister_name
    )
  end

  def assign_fellowship_for_non_admin
    return if current_user&.admin?

    @ceremony_schedule.fellowship = current_user.fellowship
  end

  def authorized_fellowship?(fellowship)
    return true if current_user&.admin?

    fellowship.present? && fellowship.id == current_user&.fellowship_id
  end

  def editable_fellowship
    return @fellowships&.first if current_user&.admin?

    current_user.fellowship
  end

  def load_fellowships
    @fellowships = if current_user&.admin?
      Fellowship.available.includes(:region)
    else
      Array(current_user.fellowship)
    end
  end

  def load_events
    @events = Event.recent_first
  end

  def set_selected_event
    @selected_event = if @ceremony_schedule
      @ceremony_schedule.event
    elsif action_name.in?(%w[new create])
      Event.open.recent_first.first || Event.recent_first.first
    elsif params[:event_id].present?
      Event.find(params[:event_id])
    else
      selected_event_from_navigation
    end
  end

  def allocation_sort_direction
    return nil unless params[:allocation_sort] == "fellowship"

    params[:allocation_direction] == "desc" ? :desc : :asc
  end

  def next_allocation_sort_direction
    case @allocation_sort_direction
    when nil then :asc
    when :asc then :desc
    else nil
    end
  end

  def allocation_rows_for(schedules)
    rows = schedules.group_by(&:fellowship).map do |fellowship, fellowship_schedules|
      allocation = CeremonyScheduleAllocation.find_or_initialize_by(event: @selected_event, fellowship: fellowship)
      allocation.spirit_count ||= fellowship_schedules.sum(&:spirit_count)
      { fellowship:, spirit_count: allocation.spirit_count, allocation: }
    end
    fellowship_order = Fellowship::AVAILABLE_NAMES.each_with_index.to_h
    rows = rows.sort_by { |row| fellowship_order.fetch(row[:fellowship].name, Float::INFINITY) } if @allocation_sort_direction == :asc
    rows = rows.sort_by { |row| fellowship_order.fetch(row[:fellowship].name, Float::INFINITY) }.reverse if @allocation_sort_direction == :desc

    next_number = 1
    rows.each do |row|
      row[:serial_number_from] = next_number
      row[:serial_number_to] = next_number + row[:spirit_count] - 1
      next_number = row[:serial_number_to] + 1
    end
  end
end
