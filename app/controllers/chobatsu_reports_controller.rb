class ChobatsuReportsController < ApplicationController
  before_action :load_form_collections

  def new
    @chobatsu_report = ChobatsuReport.new(
      ceremony_date: Date.current,
      participant_count: nil,
      serial_number_from: nil,
      serial_number_to: nil
    )
  end

  def create
    @chobatsu_report = ChobatsuReport.new(chobatsu_report_params)

    if @chobatsu_report.save
      redirect_to root_path, notice: "超抜報告を登録しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def chobatsu_report_params
    params.require(:chobatsu_report).permit(
      :ceremony_date,
      :evangelism_meeting_id,
      :assistant_name,
      :participant_count,
      :serial_number_from,
      :serial_number_to
    )
  end

  def load_form_collections
    @evangelism_meetings = EvangelismMeeting.order(:id)
    @chobatsu_reports = ChobatsuReport.includes(:evangelism_meeting).order(:serial_number_from)
    @total_serial_count = SystemSetting.total_serial_count
  rescue ActiveRecord::RecordNotFound
    @total_serial_count = 0
  end
end
