class OverseasChobatsuEntriesController < ApplicationController
  before_action :load_events
  before_action :set_selected_event
  before_action :require_admin!, only: [ :update_assignments, :auto_fill_assignments, :reset_assignments ]

  def index
    load_entries
  end

  def bulk_update
    load_entries

    OverseasChobatsuEntry.transaction do
      destroy_submitted_entries

      submitted_entries.each do |entry_id, attributes|
        entry = entry_for(entry_id)
        next unless entry
        next if entry.new_record? && entry_attributes(attributes).values.all?(&:blank?)

        entry.assign_attributes(entry_attributes(attributes))
        entry.save!
      end
    end

    redirect_to overseas_chobatsu_entries_path(event_id: @selected_event.id), notice: "海外超抜の内容を更新しました"
  rescue ActiveRecord::RecordInvalid => error
    load_entries
    @entry_errors = error.record.errors.full_messages
    render :index, status: :unprocessable_content
  end

  def update_assignments
    load_entries

    OverseasChobatsuAssignment.transaction do
      submitted_assignments.each do |serial_number, entry_id|
        serial_number = Integer(serial_number, exception: false)
        entry = @all_entries_by_id[Integer(entry_id, exception: false)]
        next unless serial_number && @serial_numbers.include?(serial_number)

        automatic_entry = @default_entries_by_serial[serial_number]
        assignment = OverseasChobatsuAssignment.find_or_initialize_by(event: @selected_event, serial_number: serial_number)
        if entry.nil? || entry == automatic_entry
          assignment.destroy! if assignment.persisted?
        else
          assignment.update!(overseas_chobatsu_entry: entry)
        end
      end
    end

    redirect_to overseas_chobatsu_entries_path(event_id: @selected_event.id), notice: "番号名簿を更新しました"
  rescue ActiveRecord::RecordInvalid => error
    load_entries
    @entry_errors = error.record.errors.full_messages
    render :index, status: :unprocessable_content
  end

  def reset_assignments
    OverseasChobatsuAssignment.where(event: @selected_event).destroy_all
    redirect_to overseas_chobatsu_entries_path(event_id: @selected_event.id), notice: "自動配分に戻しました"
  end

  def auto_fill_assignments
    load_entries
    return redirect_to(overseas_chobatsu_entries_path(event_id: @selected_event.id), alert: "引保師名を入力してください") if @all_entries.empty?

    entries_to_assign = @assignment_rows.select { |row| row[:entry].nil? }
    OverseasChobatsuAssignment.transaction do
      entries_to_assign.each_with_index do |row, index|
        OverseasChobatsuAssignment.find_or_initialize_by(event: @selected_event, serial_number: row[:serial_number]).update!(
          overseas_chobatsu_entry: @all_entries[index % @all_entries.length]
        )
      end
    end

    redirect_to overseas_chobatsu_entries_path(event_id: @selected_event.id), notice: "空欄の番号を自動割り振りしました"
  rescue ActiveRecord::RecordInvalid => error
    load_entries
    @entry_errors = error.record.errors.full_messages
    render :index, status: :unprocessable_content
  end

  def export
    load_entries

    send_data CloudflarePdfClient.render(html: render_to_string(template: "overseas_chobatsu_entries/export", layout: false)),
              filename: "#{@selected_event.name}_海外超抜.pdf",
              type: "application/pdf",
              disposition: "attachment"
  rescue CloudflarePdfClient::Error => error
    render plain: error.message, status: :service_unavailable
  end

  private

  def load_events
    @events = Event.recent_first
  end

  def set_selected_event
    @selected_event = if params[:event_id].present?
      Event.find(params[:event_id])
    else
      selected_event_from_navigation
    end
  end

  def load_entries
    @fellowships = Fellowship.available
    @editing_fellowship = if current_user.admin?
      @fellowships.find_by(id: params[:fellowship_id]) || @fellowships.first
    else
      current_user.fellowship
    end
    @entries = OverseasChobatsuEntry.where(event: @selected_event, fellowship: @editing_fellowship).order(:input_order, :id).to_a
    @entries_by_id = @entries.index_by(&:id)
    @all_entries = OverseasChobatsuEntry.where(event: @selected_event).order(:input_order, :id).to_a
    @all_entries_by_id = @all_entries.index_by(&:id)
    @special_schedule = CeremonySchedule.for_event(@selected_event).special.first
    @serial_numbers = serial_numbers_for_special_schedule
    @default_entries_by_serial = default_entries_by_serial
    @manual_assignments_by_serial = OverseasChobatsuAssignment.where(event: @selected_event).includes(:overseas_chobatsu_entry).index_by(&:serial_number)
    @assignment_rows = @serial_numbers.filter_map do |serial_number|
      automatic_entry = @default_entries_by_serial[serial_number]
      manual_assignment = @manual_assignments_by_serial[serial_number]
      entry = manual_assignment&.overseas_chobatsu_entry || automatic_entry
      { serial_number:, entry:, automatic_entry: }
    end
  end

  def submitted_entries
    entries = params.fetch(:entries, {})
    entries.respond_to?(:each) ? entries : {}
  end

  def entry_attributes(attributes)
    attributes.permit(:assistant_name, :notes)
  end

  def entry_for(entry_id)
    return unless @editing_fellowship

    if entry_id.start_with?("new-")
      OverseasChobatsuEntry.new(event: @selected_event, fellowship: @editing_fellowship)
    else
      @entries_by_id[entry_id.to_i]
    end
  end

  def destroy_submitted_entries
    entry_ids = Array(params[:deleted_entry_ids]).filter_map { |id| Integer(id, exception: false) }
    entry_ids.filter_map { |id| @entries_by_id[id] }.each(&:destroy!)
  end

  def submitted_assignments
    assignments = params.fetch(:assignments, {})
    assignments.respond_to?(:each) ? assignments : {}
  end

  def serial_numbers_for_special_schedule
    return [] unless @special_schedule&.serial_number_from && @special_schedule.serial_number_to

    (@special_schedule.serial_number_from..@special_schedule.serial_number_to).to_a
  end

  def default_entries_by_serial
    return {} if @serial_numbers.empty? || @all_entries.empty?

    @serial_numbers.zip(@all_entries).to_h
  end
end
