class ChobatsuReportsController < ApplicationController
  before_action :load_form_collections

  def new
    @chobatsu_report = ChobatsuReport.new(
      ceremony_date: Date.current,
      serial_number_from: next_available_serial_number
    )
    @chobatsu_report.serial_number_to = @chobatsu_report.serial_number_from
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
      :serial_number_to,
      :merit_fee_total
    )
  end

  def load_form_collections
    @evangelism_meetings = EvangelismMeeting.order(:id)
    @chobatsu_reports = ChobatsuReport.includes(:evangelism_meeting).order(:serial_number_from)
    @total_serial_count = SystemSetting.total_serial_count
  rescue ActiveRecord::RecordNotFound
    @total_serial_count = 0
  end

  def next_available_serial_number
    max_number = @chobatsu_reports.maximum(:serial_number_to).to_i
    next_number = max_number + 1
    next_number = 1 unless next_number.positive?
    return @total_serial_count if @total_serial_count.positive? && next_number > @total_serial_count

    next_number
  end
end
