class CeremonyScheduleAllocationSnapshot < ApplicationRecord
  belongs_to :event

  def allocation_counts
    JSON.parse(self[:allocation_counts].presence || "{}").transform_keys(&:to_i).transform_values(&:to_i)
  end

  def allocation_counts=(counts)
    self[:allocation_counts] = counts.stringify_keys.to_json
  end
end
