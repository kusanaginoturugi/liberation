class OverseasChobatsuEntriesController < ApplicationController
  before_action :load_events
  before_action :set_selected_event

  def index
    load_entries
  end

  def bulk_update
    load_entries

    submitted_entries.each do |fellowship_id, attributes|
      fellowship = @fellowships.find_by(id: fellowship_id)
      next unless fellowship

      entry = OverseasChobatsuEntry.find_or_initialize_by(event: @selected_event, fellowship: fellowship)
      entry.assign_attributes(entry_attributes(attributes))
      entry.save!
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
    @entries_by_fellowship_id = OverseasChobatsuEntry.where(event: @selected_event).index_by(&:fellowship_id)
  end

  def submitted_entries
    entries = params.fetch(:entries, {})
    return entries if current_user.admin?

    fellowship_id = current_user.fellowship_id.to_s
    entries.slice(fellowship_id)
  end

  def entry_attributes(attributes)
    attributes.permit(:assistant_name, :spirit_count, :notes)
  end
end
