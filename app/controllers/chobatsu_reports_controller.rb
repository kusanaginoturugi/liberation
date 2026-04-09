class ChobatsuReportsController < ApplicationController
  allow_unauthenticated_access only: [:index]

  before_action :load_index_collections, only: [:index]
  before_action :load_form_collections, only: [:new, :create]

  def index
  end

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

  def load_index_collections
    @regions = Region.order(:name)
    @selected_region = selected_region_for_index
    region_meetings = @selected_region.evangelism_meetings
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region(@selected_region.id)
    @total_serial_count = SystemSetting.total_serial_count
  rescue ActiveRecord::RecordNotFound
    @regions = []
    @legend_evangelism_meetings = []
    @chobatsu_reports = ChobatsuReport.none
    @total_serial_count = 0
  end

  def load_form_collections
    region_meetings = current_user.region.evangelism_meetings
    @evangelism_meetings = region_meetings.active.display_sorted
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region(current_user.region_id)
    @total_serial_count = SystemSetting.total_serial_count
  rescue ActiveRecord::RecordNotFound
    @total_serial_count = 0
  end

  def reports_for_region(region_id)
    ChobatsuReport.joins(:evangelism_meeting)
                  .where(evangelism_meetings: { region_id: })
                  .includes(:evangelism_meeting)
                  .order(:serial_number_from)
  end

  def selected_region_for_index
    return Region.find(params[:region_id]) if params[:region_id].present?
    return current_user.region if current_user

    Region.order(:name).first || Region.new(name: "未設定")
  end
end
