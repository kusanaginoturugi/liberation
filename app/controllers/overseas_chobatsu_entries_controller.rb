class OverseasChobatsuEntriesController < ApplicationController
  before_action :load_events
  before_action :set_selected_event

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
    @entries = OverseasChobatsuEntry.where(event: @selected_event, fellowship: @editing_fellowship).order(:serial_number, :id).to_a
    @entries_by_id = @entries.index_by(&:id)
    @export_entries = OverseasChobatsuEntry.where(event: @selected_event).includes(:fellowship).order(:serial_number, :id)
  end

  def submitted_entries
    entries = params.fetch(:entries, {})
    entries.respond_to?(:each) ? entries : {}
  end

  def entry_attributes(attributes)
    attributes.permit(:serial_number, :assistant_name, :notes)
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
end
