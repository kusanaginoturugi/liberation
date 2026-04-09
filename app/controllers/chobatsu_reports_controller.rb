class ChobatsuReportsController < ApplicationController
  allow_unauthenticated_access only: [:index, :summary]

  before_action :load_index_collections, only: [:index]
  before_action :load_summary_collections, only: [:summary]
  before_action :load_form_collections, only: [:new, :create, :export]

  def index
  end

  def new
    @chobatsu_report = ChobatsuReport.new(
      ceremony_date: Date.current,
      event: @selected_event,
      participant_count: nil,
      serial_number_from: nil,
      serial_number_to: nil
    )
  end

  def summary
  end

  def export
    @export_reports = @chobatsu_reports.includes(:user).reorder(ceremony_date: :asc, id: :asc)

    respond_to do |format|
      format.csv do
        send_data generate_csv(@export_reports),
                  filename: export_filename("csv"),
                  type: "text/csv; charset=utf-8"
      end

      format.pdf do
        response.headers["Content-Disposition"] = %(inline; filename="#{export_filename("pdf")}")
        render :export, layout: false
      end
    end
  end

  def create
    @chobatsu_report = ChobatsuReport.new(chobatsu_report_params)
    @chobatsu_report.user = current_user

    if @chobatsu_report.save
      redirect_to root_path, notice: "挙行報告を登録しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def chobatsu_report_params
    params.require(:chobatsu_report).permit(
      :ceremony_date,
      :event_id,
      :evangelism_meeting_id,
      :participant_count,
      :serial_number_from,
      :serial_number_to
    )
  end

  def load_index_collections
    @regions = Region.order(:name)
    @events = Event.recent_first
    @selected_region = selected_region_for_index
    @selected_event = selected_event_for_index
    region_meetings = @selected_region.evangelism_meetings
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region_and_event(@selected_region.id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, @selected_region)
  rescue ActiveRecord::RecordNotFound
    @regions = []
    @events = []
    @legend_evangelism_meetings = []
    @chobatsu_reports = ChobatsuReport.none
    @total_serial_count = 0
  end

  def load_form_collections
    @events = Event.recent_first
    @selected_event = selected_event_for_form
    region_meetings = current_user.region.evangelism_meetings
    @evangelism_meetings = region_meetings.active.display_sorted
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region_and_event(current_user.region_id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, current_user.region)
  rescue ActiveRecord::RecordNotFound
    @events = []
    @total_serial_count = 0
  end

  def load_summary_collections
    @regions = Region.order(:name)
    @events = Event.recent_first
    @selected_region = selected_region_for_index
    @selected_event = selected_event_for_index
    @summary_sort_direction = summary_sort_direction
    @summary_reports = reports_for_region_and_event(@selected_region.id, @selected_event.id)
                     .includes(:user)
                     .reorder(ceremony_date: @summary_sort_direction, id: @summary_sort_direction)
  rescue ActiveRecord::RecordNotFound
    @regions = []
    @events = []
    @summary_reports = ChobatsuReport.none
  end

  def reports_for_region_and_event(region_id, event_id)
    ChobatsuReport.where(region_id: region_id, event_id: event_id)
                  .includes(:evangelism_meeting)
                  .order(:serial_number_from)
  end

  def selected_region_for_index
    return Region.find(primary_region_id) if single_region_mode?
    return Region.find(params[:region_id]) if params[:region_id].present?
    return current_user.region if current_user

    Region.order(:name).first || Region.new(name: "未設定")
  end

  def selected_event_for_index
    return Event.find(params[:event_id]) if params[:event_id].present?

    Event.recent_first.first || Event.new(name: "未設定")
  end

  def selected_event_for_form
    return Event.find(chobatsu_report_params[:event_id]) if action_name == "create" && chobatsu_report_params[:event_id].present?

    selected_event_for_index
  end

  def summary_sort_direction
    params[:direction] == "desc" ? :desc : :asc
  end

  def total_serial_count_for(event, region)
    EventDetail.find_by!(event: event, region: region).total_serial_count
  end

  def generate_csv(reports)
    lines = []
    lines << csv_line(["挙行日", "伝道会名", "超抜霊数", "功徳費合計", "みろく寺分", "聖院還付金", "伝道会還付金", "入力者名"])

    reports.each do |report|
      lines << csv_line([
        report.ceremony_date.strftime("%Y/%m/%d"),
        report.evangelism_meeting.name,
        report.participant_count,
        report.calculated_merit_fee_total,
        report.mirokuji_share,
        report.region_refund,
        report.evangelism_meeting_refund,
        report.user&.name || "未設定"
      ])
    end

    lines.join
  end

  def export_filename(extension)
    event_token = @selected_event&.id || "event"
    "gyoko_hokoku_#{event_token}.#{extension}"
  end

  def csv_line(values)
    values.map { |value| csv_escape(value) }.join(",") + "\n"
  end

  def csv_escape(value)
    text = value.to_s
    return text unless text.match?(/[",\n]/)

    %("#{text.gsub('"', '""')}")
  end
end
