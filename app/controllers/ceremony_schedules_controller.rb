class CeremonySchedulesController < ApplicationController
  allow_unauthenticated_access only: [ :index, :export ]

  before_action :set_ceremony_schedule, only: [ :edit, :update, :destroy ]
  before_action :load_events
  before_action :set_selected_event
  before_action :authorize_ceremony_schedule_edit!, only: [ :edit, :update, :destroy ]
  before_action :load_fellowships, only: [ :new, :create, :edit, :update ]

  def index
    @schedule_sort_direction = schedule_sort_direction
    @next_schedule_sort_direction = next_schedule_sort_direction
    @ceremony_schedules = schedules_for_selected_event
    @regular_spirit_total = regular_schedules_for_selected_event.sum(&:spirit_count)
    @qualified_spirit_count = qualified_spirit_count_for(@selected_event)
    @allocation_sort_direction = allocation_sort_direction
    @next_allocation_sort_direction = next_allocation_sort_direction
    @distribution_additions = CeremonyScheduleAllocation.distribution_additions_for(@selected_event)
    @allocation_rows = allocation_rows_for(regular_schedules_for_selected_event)
    @allocation_shortfall = allocation_shortfall_for(@selected_event, @qualified_spirit_count)
    @distribution_undo_available = CeremonyScheduleAllocationSnapshot.exists?(event: @selected_event)
  end

  def export
    @schedule_sort_direction = schedule_sort_direction
    @ceremony_schedules = schedules_for_selected_event
    @regular_spirit_total = regular_schedules_for_selected_event.sum(&:spirit_count)
    @qualified_spirit_count = qualified_spirit_count_for(@selected_event)
    @allocation_sort_direction = allocation_sort_direction
    @distribution_additions = CeremonyScheduleAllocation.distribution_additions_for(@selected_event)
    @allocation_rows = allocation_rows_for(regular_schedules_for_selected_event)

    send_data CloudflarePdfClient.render(html: render_to_string(template: "ceremony_schedules/export", layout: false)),
              filename: "#{@selected_event.name}_挙行予定表.pdf",
              type: "application/pdf",
              disposition: "attachment"
  rescue CloudflarePdfClient::Error => e
    render plain: e.message, status: :service_unavailable
  end

  def new
    @ceremony_schedule = CeremonySchedule.new(fellowship: editable_fellowship, event: @selected_event)
  end

  def create
    @ceremony_schedule = CeremonySchedule.new(ceremony_schedule_params)
    @ceremony_schedule.event = @selected_event
    apply_special_schedule_defaults
    apply_joint_schedule_details
    assign_fellowship_for_non_admin

    if authorized_fellowship?(@ceremony_schedule.fellowship) && save_ceremony_schedule
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
    apply_special_schedule_defaults
    apply_joint_schedule_details
    assign_fellowship_for_non_admin

    if authorized_fellowship?(@ceremony_schedule.fellowship) && save_ceremony_schedule
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
    return if @ceremony_schedule.special_schedule?
    if @ceremony_schedule.joint_schedule?
      redirect_to ceremony_schedules_path, alert: "合同予定は管理者のみ編集できます"
      return
    end
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
      :serial_number_from,
      :serial_number_to,
      :minister_name,
      :special_schedule,
      :joint_schedule
    )
  end

  def apply_special_schedule_defaults
    return unless @ceremony_schedule.special_schedule?

    fellowship = special_fellowship
    unless fellowship
      @ceremony_schedule.errors.add(:base, "聖明王院が見つかりません")
      return
    end

    @ceremony_schedule.fellowship = fellowship
    @ceremony_schedule.place = fellowship.name
  end

  def apply_joint_schedule_details
    @joint_schedule_contributions = []
    @joint_schedule_valid = true
    return unless @ceremony_schedule.joint_schedule?

    if @ceremony_schedule.special_schedule?
      @joint_schedule_valid = false
      return
    end

    primary_fellowship = @ceremony_schedule.fellowship
    secondary_fellowship = Fellowship.available.find_by(id: joint_schedule_params[:joint_fellowship_id])
    primary_assistant_count = whole_number(joint_schedule_params[:primary_assistant_count])
    secondary_assistant_count = whole_number(joint_schedule_params[:secondary_assistant_count])
    primary_spirit_count = whole_number(joint_schedule_params[:primary_spirit_count])
    secondary_spirit_count = whole_number(joint_schedule_params[:secondary_spirit_count])

    add_joint_schedule_error("合同する2つ目の伝道会を選択してください") unless secondary_fellowship
    add_joint_schedule_error("合同する伝道会は異なる伝道会を選択してください") if primary_fellowship && primary_fellowship == secondary_fellowship
    add_joint_schedule_error("1つ目の伝道会の引保師数を入力してください") if primary_assistant_count.nil?
    add_joint_schedule_error("2つ目の伝道会の引保師数を入力してください") if secondary_assistant_count.nil?
    add_joint_schedule_error("1つ目の伝道会の霊数を入力してください") if primary_spirit_count.nil?
    add_joint_schedule_error("2つ目の伝道会の霊数を入力してください") if secondary_spirit_count.nil?
    return if @ceremony_schedule.errors.any?

    @ceremony_schedule.assistant_count = primary_assistant_count + secondary_assistant_count
    @ceremony_schedule.spirit_count = primary_spirit_count + secondary_spirit_count
    @joint_schedule_contributions = [
      { fellowship: primary_fellowship, assistant_count: primary_assistant_count, spirit_count: primary_spirit_count },
      { fellowship: secondary_fellowship, assistant_count: secondary_assistant_count, spirit_count: secondary_spirit_count }
    ]
  end

  def joint_schedule_params
    params.fetch(:ceremony_schedule, {}).permit(
      :joint_fellowship_id,
      :primary_assistant_count,
      :secondary_assistant_count,
      :primary_spirit_count,
      :secondary_spirit_count
    )
  end

  def whole_number(value)
    number = Integer(value, exception: false)
    number if number && number >= 0
  end

  def add_joint_schedule_error(message)
    @joint_schedule_valid = false
    @ceremony_schedule.errors.add(:base, message)
  end

  def save_ceremony_schedule
    return false unless @joint_schedule_valid

    CeremonySchedule.transaction do
      @ceremony_schedule.save!
      @ceremony_schedule.ceremony_schedule_fellowships.destroy_all
      @joint_schedule_contributions.each do |contribution|
        @ceremony_schedule.ceremony_schedule_fellowships.create!(contribution)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def assign_fellowship_for_non_admin
    return if @ceremony_schedule.special_schedule?
    return if current_user&.admin?

    @ceremony_schedule.fellowship = current_user.fellowship
  end

  def authorized_fellowship?(fellowship)
    return current_user&.admin? if @ceremony_schedule.special_schedule?
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
    @special_fellowship = special_fellowship
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

  def schedule_sort_direction
    return nil unless params[:schedule_sort] == "fellowship"

    params[:schedule_direction] == "desc" ? :desc : :asc
  end

  def next_allocation_sort_direction
    case @allocation_sort_direction
    when nil then :asc
    when :asc then :desc
    else nil
    end
  end

  def next_schedule_sort_direction
    case @schedule_sort_direction
    when nil then :asc
    when :asc then :desc
    else nil
    end
  end

  def schedules_for_selected_event
    schedules = chronological_schedules_for_selected_event
    return schedules unless @schedule_sort_direction

    fellowship_order = Fellowship::AVAILABLE_NAMES.each_with_index.to_h
    schedules = schedules.sort_by do |schedule|
      [ fellowship_order.fetch(schedule.display_name, Float::INFINITY), schedule.ceremony_at, schedule.id ]
    end
    @schedule_sort_direction == :desc ? schedules.reverse : schedules
  end

  def chronological_schedules_for_selected_event
    CeremonySchedule.for_event(@selected_event).chronological.to_a
  end

  def regular_schedules_for_selected_event
    CeremonySchedule.for_event(@selected_event).regular.chronological.to_a
  end

  def special_fellowship
    @special_fellowship ||= Fellowship.find_by(name: "聖明王院")
  end

  def allocation_rows_for(schedules)
    return [] if schedules.empty?

    schedules_by_fellowship = Hash.new { |hash, key| hash[key] = [] }
    schedules.each do |schedule|
      schedule.allocation_contributions.each do |fellowship, spirit_count|
        schedules_by_fellowship[fellowship] << spirit_count
      end
    end
    fellowships = schedules_by_fellowship.keys
    eligible_fellowships = Fellowship.available.where("altar_count > 0").to_a
    fellowships += eligible_fellowships.reject { |fellowship| fellowships.include?(fellowship) }

    rows = fellowships.map do |fellowship|
      fellowship_spirit_counts = schedules_by_fellowship.fetch(fellowship, [])
      allocation = CeremonyScheduleAllocation.find_or_initialize_by(event: @selected_event, fellowship: fellowship)
      allocation.spirit_count ||= fellowship_spirit_counts.sum
      {
        fellowship:,
        altar_count: fellowship.altar_count,
        spirit_count: allocation.spirit_count,
        allocation:,
        distribution_addition: @distribution_additions.fetch(fellowship.id, 0)
      }
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

  def qualified_spirit_count_for(event)
    event.event_details.find_by(region_id: primary_region_id)&.total_serial_count
  end

  def allocation_shortfall_for(event, qualified_spirit_count)
    return 0 unless qualified_spirit_count

    [ qualified_spirit_count - CeremonyScheduleAllocation.allocated_spirit_count_for(event), 0 ].max
  end
end
