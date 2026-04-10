class ChobatsuReportsController < ApplicationController
  allow_unauthenticated_access only: [:index, :summary, :export]

  before_action :load_index_collections, only: [:index]
  before_action :load_summary_collections, only: [:summary]
  before_action :load_form_collections, only: [:new, :create]
  before_action :load_export_collections, only: [:export]
  before_action :set_report, only: [:edit, :update, :destroy]
  before_action :authorize_report_edit!, only: [:edit, :update]
  before_action :require_admin!, only: [:destroy]
  before_action :load_edit_collections, only: [:edit, :update]

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
    @export_reports = reports_for_region_and_event(@selected_region.id, @selected_event.id)
                      .includes(:user)
                      .reorder(ceremony_date: :asc, id: :asc)

    respond_to do |format|
      format.html do
        render :export, layout: false
      end

      format.csv do
        send_data generate_csv(@export_reports),
                  filename: export_filename("csv"),
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def create
    @chobatsu_report = ChobatsuReport.new(chobatsu_report_params)
    @chobatsu_report.user = current_user
    ensure_event_detail_for(@chobatsu_report.event, @chobatsu_report.evangelism_meeting&.region)

    if @chobatsu_report.save
      redirect_to root_path, notice: "挙行報告を登録しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @chobatsu_report.assign_attributes(chobatsu_report_params)
    ensure_event_detail_for(@chobatsu_report.event, @chobatsu_report.evangelism_meeting&.region)

    if @chobatsu_report.save
      redirect_to summary_chobatsu_reports_path(event_id: @chobatsu_report.event_id), notice: "挙行報告を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    event_id = @chobatsu_report.event_id
    @chobatsu_report.destroy!
    redirect_to summary_chobatsu_reports_path(event_id: event_id), notice: "挙行報告を削除しました"
  end

  private

  def set_report
    @chobatsu_report = ChobatsuReport.find(params[:id])
  end

  def authorize_report_edit!
    return if current_user&.admin?
    return if @chobatsu_report.user_id == current_user&.id

    redirect_to root_path, alert: "編集権限がありません"
  end

  def chobatsu_report_params
    params.require(:chobatsu_report).permit(
      :ceremony_date,
      :evangelism_meeting_id,
      :participant_count,
      :serial_number_from,
      :serial_number_to,
      :noah_card_count,
      :notes
    ).tap do |attrs|
      attrs[:event_id] = @selected_event.id if action_name == "create" && @selected_event&.id.present?
    end
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
    @events = Event.open.recent_first
    @selected_event = selected_event_for_form
    region = current_operational_region
    ensure_event_detail_for(@selected_event, region)
    region_meetings = region.evangelism_meetings
    @evangelism_meetings = region_meetings.active.display_sorted
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region_and_event(region.id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, region)
  rescue ActiveRecord::RecordNotFound
    @events = []
    @total_serial_count = 0
  end

  def load_edit_collections
    @selected_event = @chobatsu_report.event
    region = @chobatsu_report.region
    @events = Event.recent_first
    region_meetings = region.evangelism_meetings
    @evangelism_meetings = region_meetings.active.display_sorted
    @legend_evangelism_meetings = region_meetings.display_sorted
    @chobatsu_reports = reports_for_region_and_event(region.id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, region)
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

  def load_export_collections
    @regions = Region.order(:name)
    @events = Event.recent_first
    @selected_region = selected_region_for_index
    @selected_event = selected_event_for_index
  rescue ActiveRecord::RecordNotFound
    @regions = []
    @events = []
    @selected_region = Region.new(name: "未設定")
    @selected_event = Event.new(name: "未設定")
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
    Event.open.recent_first.first || Event.recent_first.first || Event.new(name: "未設定")
  end

  def summary_sort_direction
    params[:direction] == "desc" ? :desc : :asc
  end

  def total_serial_count_for(event, region)
    EventDetail.find_by(event: event, region: region)&.total_serial_count.to_i
  end

  def current_operational_region
    return Region.find(primary_region_id) if single_region_mode?

    current_user.region
  end

  def ensure_event_detail_for(event, region)
    return if event.blank? || region.blank?

    EventDetail.find_or_create_by!(event: event, region: region) do |detail|
      detail.total_serial_count = EventDetail::DEFAULT_TOTAL_SERIAL_COUNT
    end
  end

  def generate_csv(reports)
    lines = []
    lines << csv_line(["挙行日", "伝道会名", "超抜霊数", "(内)ノアカード分", "功徳費合計", "みろく寺分(ノア分勘案せず)", "聖院還付金", "備考欄", "入力者名"])

    reports.each do |report|
      lines << csv_line([
        report.ceremony_date.strftime("%Y/%m/%d"),
        report.evangelism_meeting.name,
        report.participant_count,
        report.noah_card_count,
        report.calculated_merit_fee_total,
        report.mirokuji_share,
        report.region_refund,
        report.notes,
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
