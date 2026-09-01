class CeremonyScheduleAllocationsController < ApplicationController
  before_action :require_admin!

  def create
    allocation = CeremonyScheduleAllocation.new(allocation_params)
    save_allocation(allocation)
  end

  def update
    allocation = CeremonyScheduleAllocation.find(params[:id])
    allocation.assign_attributes(allocation_params)
    save_allocation(allocation)
  end

  def distribute_shortfall
    event = Event.find(params[:event_id])
    qualified_spirit_count = EventDetail.find_by(event:, region_id: primary_region_id)&.total_serial_count
    unless qualified_spirit_count
      redirect_to ceremony_schedules_path(event_id: event.id), alert: "合格霊数が設定されていません"
      return
    end

    result = CeremonyScheduleAllocation.distribute_shortfall!(event:, qualified_spirit_count:)
    message = if result[:distributed]
      "不足分 #{result[:shortfall]}霊を壇数で配分しました"
    else
      "配分する不足分はありません"
    end
    redirect_to ceremony_schedules_path(event_id: event.id), notice: message
  rescue CeremonyScheduleAllocation::DistributionError, ActiveRecord::RecordInvalid => e
    redirect_to ceremony_schedules_path(event_id: event.id), alert: e.message
  end

  private

  def allocation_params
    params.require(:ceremony_schedule_allocation).permit(:event_id, :fellowship_id, :spirit_count)
  end

  def save_allocation(allocation)
    if allocation.save
      redirect_to ceremony_schedules_path(event_id: allocation.event_id), notice: "割り振り霊数を更新しました"
    else
      redirect_to ceremony_schedules_path(event_id: allocation.event_id), alert: allocation.errors.full_messages.to_sentence
    end
  end
end
