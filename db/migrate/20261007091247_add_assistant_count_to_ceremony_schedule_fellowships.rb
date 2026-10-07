class AddAssistantCountToCeremonyScheduleFellowships < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremony_schedule_fellowships, :assistant_count, :integer
  end
end
