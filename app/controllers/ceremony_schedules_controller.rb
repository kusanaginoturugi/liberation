class CeremonySchedulesController < ApplicationController
  allow_unauthenticated_access only: [ :index ]

  before_action :set_ceremony_schedule, only: [ :edit, :update ]
  before_action :authorize_ceremony_schedule_edit!, only: [ :edit, :update ]
  before_action :load_fellowships, only: [ :new, :create, :edit, :update ]

  def index
    @ceremony_schedules = CeremonySchedule.chronological
  end

  def new
    @ceremony_schedule = CeremonySchedule.new(fellowship: editable_fellowship)
  end

  def create
    @ceremony_schedule = CeremonySchedule.new(ceremony_schedule_params)
    assign_fellowship_for_non_admin

    if authorized_fellowship?(@ceremony_schedule.fellowship) && @ceremony_schedule.save
      redirect_to ceremony_schedules_path, notice: "挙行予定を追加しました"
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
      redirect_to ceremony_schedules_path, notice: "挙行予定を更新しました"
    else
      @ceremony_schedule.errors.add(:fellowship, "の予定を編集する権限がありません") unless authorized_fellowship?(@ceremony_schedule.fellowship)
      render :edit, status: :unprocessable_content
    end
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
end
