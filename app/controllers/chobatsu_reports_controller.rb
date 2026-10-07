class ChobatsuReportsController < ApplicationController
  allow_unauthenticated_access only: [ :index, :summary, :export ]

  before_action :load_index_collections, only: [ :index ]
  before_action :load_summary_collections, only: [ :summary ]
  before_action :load_form_collections, only: [ :new, :create ]
  before_action :load_export_collections, only: [ :export ]
  before_action :set_report, only: [ :edit, :update, :destroy ]
  before_action :require_open_report_event!, only: [ :edit, :update, :destroy ]
  before_action :authorize_report_edit!, only: [ :edit, :update ]
  before_action :require_admin!, only: [ :destroy ]
  before_action :load_edit_collections, only: [ :edit, :update ]

  def index
  end

  def new
    if (schedule = report_schedule_from_params)
      if (report = schedule.chobatsu_report)
        redirect_to edit_chobatsu_report_path(report)
        return
      end

      @chobatsu_report = report_from_schedule(schedule)
      return
    end

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
        send_data csv_data_for_export(@export_reports),
                  filename: export_filename("csv"),
                  type: "text/csv; charset=#{csv_charset}"
      end
    end
  end

  def create
    @chobatsu_report = ChobatsuReport.new(chobatsu_report_params)
    @chobatsu_report.user = current_user
    apply_joint_report_details
    ensure_event_detail_for(@chobatsu_report.event, @chobatsu_report.fellowship&.region)

    if @joint_report_valid && save_chobatsu_report
      redirect_to root_path, notice: "挙行報告を登録しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @chobatsu_report.assign_attributes(chobatsu_report_params)
    apply_joint_report_details
    ensure_event_detail_for(@chobatsu_report.event, @chobatsu_report.fellowship&.region)

    if @joint_report_valid && save_chobatsu_report
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

  def require_open_report_event!
    return unless @chobatsu_report.event.closed?

    redirect_to summary_chobatsu_reports_path(event_id: @chobatsu_report.event_id), alert: "終了した超抜式の報告は編集・削除できません"
  end

  def chobatsu_report_params
    params.require(:chobatsu_report).permit(
      :ceremony_date,
      :fellowship_id,
      :participant_count,
      :serial_number_from,
      :serial_number_to,
      :noah_card_count,
      :notes,
      :joint_report,
      :ceremony_schedule_id,
      serial_number_ranges_attributes: [ :id, :serial_number_from, :serial_number_to, :_destroy ]
    ).tap do |attrs|
      attrs[:event_id] = @selected_event.id if action_name == "create" && @selected_event&.id.present?
    end
  end

  def joint_report_params
    params.fetch(:chobatsu_report, {}).permit(
      :joint_primary_fellowship_id,
      :joint_secondary_fellowship_id,
      :joint_primary_participant_count,
      :joint_secondary_participant_count,
      :joint_primary_serial_number_from,
      :joint_primary_serial_number_to,
      :joint_secondary_serial_number_from,
      :joint_secondary_serial_number_to,
      joint_primary_additional_ranges_attributes: [ :serial_number_from, :serial_number_to, :_destroy ],
      joint_secondary_additional_ranges_attributes: [ :serial_number_from, :serial_number_to, :_destroy ]
    )
  end

  def apply_joint_report_details
    @joint_report_contributions = []
    @joint_report_valid = true
    return unless @chobatsu_report.joint_report?

    details = joint_report_params
    assign_joint_report_form_values(details)

    primary_fellowship = @fellowships.find { |fellowship| fellowship.id == details[:joint_primary_fellowship_id].to_i }
    secondary_fellowship = @fellowships.find { |fellowship| fellowship.id == details[:joint_secondary_fellowship_id].to_i }
    primary_participant_count = nonnegative_integer(details[:joint_primary_participant_count])
    secondary_participant_count = nonnegative_integer(details[:joint_secondary_participant_count])
    primary_from = positive_integer(details[:joint_primary_serial_number_from])
    primary_to = positive_integer(details[:joint_primary_serial_number_to]) || primary_from
    secondary_from = positive_integer(details[:joint_secondary_serial_number_from])
    secondary_to = positive_integer(details[:joint_secondary_serial_number_to]) || secondary_from
    primary_additional_ranges = joint_additional_ranges(details[:joint_primary_additional_ranges_attributes])
    secondary_additional_ranges = joint_additional_ranges(details[:joint_secondary_additional_ranges_attributes])

    add_joint_report_error("合同する1つ目の伝道会を選択してください") unless primary_fellowship
    add_joint_report_error("合同する2つ目の伝道会を選択してください") unless secondary_fellowship
    add_joint_report_error("合同する伝道会は異なる伝道会を選択してください") if primary_fellowship && primary_fellowship == secondary_fellowship
    add_joint_report_error("1つ目の伝道会の超抜引保師数を入力してください") if primary_participant_count.nil?
    add_joint_report_error("2つ目の伝道会の超抜引保師数を入力してください") if secondary_participant_count.nil?
    add_joint_report_error("1つ目の伝道会の使用修霊番号(始)を入力してください") if primary_from.nil?
    add_joint_report_error("2つ目の伝道会の使用修霊番号(始)を入力してください") if secondary_from.nil?
    add_joint_report_error("1つ目の伝道会の使用修霊番号(終)は始以上にしてください") if primary_from && primary_to < primary_from
    add_joint_report_error("2つ目の伝道会の使用修霊番号(終)は始以上にしてください") if secondary_from && secondary_to < secondary_from
    return if @chobatsu_report.errors.any?

    @chobatsu_report.fellowship = primary_fellowship
    @chobatsu_report.participant_count = primary_participant_count + secondary_participant_count
    @chobatsu_report.serial_number_from = primary_from
    @chobatsu_report.serial_number_to = primary_to
    @joint_report_contributions = [
      build_joint_contribution(primary_fellowship, primary_participant_count, primary_from, primary_to, primary_additional_ranges),
      build_joint_contribution(secondary_fellowship, secondary_participant_count, secondary_from, secondary_to, secondary_additional_ranges)
    ]
    @chobatsu_report.joint_range_contributions = @joint_report_contributions
  end

  def assign_joint_report_form_values(details)
    @chobatsu_report.joint_primary_fellowship_id = details[:joint_primary_fellowship_id]
    @chobatsu_report.joint_secondary_fellowship_id = details[:joint_secondary_fellowship_id]
    @chobatsu_report.joint_primary_participant_count = details[:joint_primary_participant_count]
    @chobatsu_report.joint_secondary_participant_count = details[:joint_secondary_participant_count]
    @chobatsu_report.joint_primary_serial_number_from = details[:joint_primary_serial_number_from]
    @chobatsu_report.joint_primary_serial_number_to = details[:joint_primary_serial_number_to]
    @chobatsu_report.joint_secondary_serial_number_from = details[:joint_secondary_serial_number_from]
    @chobatsu_report.joint_secondary_serial_number_to = details[:joint_secondary_serial_number_to]
  end

  def add_joint_report_error(message)
    @joint_report_valid = false
    @chobatsu_report.errors.add(:base, message)
  end

  def nonnegative_integer(value)
    number = Integer(value, exception: false)
    number if number && number >= 0
  end

  def positive_integer(value)
    number = Integer(value, exception: false)
    number if number && number.positive?
  end

  def save_chobatsu_report
    ChobatsuReport.transaction do
      @chobatsu_report.save!
      @chobatsu_report.chobatsu_report_fellowships.destroy_all
      @joint_report_contributions.each do |contribution|
        contribution.chobatsu_report = @chobatsu_report
        contribution.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def joint_additional_ranges(attributes)
    attributes.to_h.values.filter_map do |range|
      next if ActiveModel::Type::Boolean.new.cast(range[:_destroy])

      from = positive_integer(range[:serial_number_from])
      to = positive_integer(range[:serial_number_to]) || from
      { serial_number_from: from, serial_number_to: to }
    end
  end

  def build_joint_contribution(fellowship, participant_count, serial_number_from, serial_number_to, additional_ranges)
    ChobatsuReportFellowship.new(
      fellowship: fellowship,
      participant_count: participant_count,
      serial_number_from: serial_number_from,
      serial_number_to: serial_number_to
    ).tap do |contribution|
      additional_ranges.each do |range|
        contribution.additional_serial_number_ranges.build(range)
      end
    end
  end

  def load_index_collections
    @regions = Region.order(:name)
    @events = Event.recent_first
    @selected_region = selected_region_for_index
    @selected_event = selected_event_for_index
    region_meetings = @selected_region.fellowships
    @legend_fellowships = region_meetings.enabled.display_sorted
    @chobatsu_reports = reports_for_region_and_event(@selected_region.id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, @selected_region)
  rescue ActiveRecord::RecordNotFound
    @regions = []
    @events = []
    @legend_fellowships = []
    @chobatsu_reports = ChobatsuReport.none
    @total_serial_count = 0
  end

  def load_form_collections
    @events = Event.open.recent_first
    schedule = report_schedule_from_params
    @selected_event = schedule&.event || selected_event_for_form
    region = schedule&.fellowship&.region || current_operational_region
    ensure_event_detail_for(@selected_event, region)
    region_meetings = region.fellowships
    @fellowships = region_meetings.active.enabled.display_sorted
    @legend_fellowships = region_meetings.enabled.display_sorted
    @chobatsu_reports = reports_for_region_and_event(region.id, @selected_event.id)
    @total_serial_count = total_serial_count_for(@selected_event, region)
  rescue ActiveRecord::RecordNotFound
    @events = []
    @total_serial_count = 0
  end

  def report_schedule_from_params
    return unless params[:ceremony_schedule_id].present?

    CeremonySchedule.includes(:fellowship, ceremony_schedule_fellowships: :fellowship).find_by(id: params[:ceremony_schedule_id])
  end

  def report_from_schedule(schedule)
    report = ChobatsuReport.new(
      ceremony_date: schedule.ceremony_at.to_date,
      ceremony_schedule: schedule,
      event: schedule.event,
      fellowship: schedule.fellowship,
      participant_count: schedule.assistant_count,
      serial_number_from: nil,
      serial_number_to: nil,
      joint_report: schedule.joint_schedule?
    )
    return report unless schedule.joint_schedule?

    secondary = schedule.joint_secondary_fellowship
    report.joint_primary_fellowship_id = schedule.fellowship_id
    report.joint_secondary_fellowship_id = secondary&.id
    report.joint_primary_participant_count = schedule.joint_primary_assistant_count
    report.joint_secondary_participant_count = schedule.joint_secondary_assistant_count
    report
  end

  def load_edit_collections
    @selected_event = @chobatsu_report.event
    region = @chobatsu_report.region
    @events = Event.recent_first
    region_meetings = region.fellowships
    @fellowships = region_meetings.active.enabled.display_sorted
    @legend_fellowships = region_meetings.enabled.display_sorted
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
    @summary_sort_column = summary_sort_column
    @summary_sort_direction = summary_sort_direction
    @summary_reports = reports_for_region_and_event(@selected_region.id, @selected_event.id)
                     .includes(:user)
                     .yield_self { |reports| ordered_summary_reports(reports) }
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
                  .includes(:fellowship, chobatsu_report_fellowships: :fellowship)
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

    selected_event_from_navigation || Event.new(name: "未設定")
  end

  def selected_event_for_form
    Event.open.recent_first.first || Event.recent_first.first || Event.new(name: "未設定")
  end

  def summary_sort_direction
    params[:direction] == "desc" ? :desc : :asc
  end

  def summary_sort_column
    params[:sort] == "ceremony_date" ? :ceremony_date : :fellowship
  end

  def ordered_summary_reports(reports)
    case @summary_sort_column
    when :ceremony_date
      reports.reorder(ceremony_date: @summary_sort_direction, id: @summary_sort_direction)
    else
      reports.joins(:fellowship)
             .reorder(
               Fellowship.arel_table[:display_order].public_send(@summary_sort_direction),
               Fellowship.arel_table[:id].public_send(@summary_sort_direction),
               ChobatsuReport.arel_table[:ceremony_date].asc,
               ChobatsuReport.arel_table[:id].asc
             )
    end
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
    lines << csv_line([ "挙行日", "伝道会名", "超抜引保師数", "超抜霊数", "(内)ノアカード分", "功徳費合計", "みろく寺分(ノア分勘案せず)", "聖院還付金", "備考欄", "入力者名" ])

    reports.each do |report|
      lines << csv_line([
        report.ceremony_date.strftime("%Y/%m/%d"),
        report.report_display_name,
        report.participant_count_lines.join("\n"),
        report.usage_count_lines.join("\n"),
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

  def csv_data_for_export(reports)
    csv = generate_csv(reports)

    case csv_encoding
    when "utf8_bom"
      "\uFEFF" + csv
    when "sjis"
      csv.encode(Encoding::Windows_31J, invalid: :replace, undef: :replace, replace: "?")
    else
      csv
    end
  end

  def csv_encoding
    value = params[:encoding].to_s
    return value if %w[utf8 utf8_bom sjis].include?(value)

    "utf8"
  end

  def csv_charset
    csv_encoding == "sjis" ? "windows-31j" : "utf-8"
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
