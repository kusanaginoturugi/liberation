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
