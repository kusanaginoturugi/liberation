class OverseasChobatsuAssignment < ApplicationRecord
  belongs_to :event
  belongs_to :overseas_chobatsu_entry

  validates :serial_number, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, uniqueness: { scope: :event_id }
  validate :entry_belongs_to_same_event

  private

  def entry_belongs_to_same_event
    return unless overseas_chobatsu_entry && event
    return if overseas_chobatsu_entry.event_id == event_id

    errors.add(:overseas_chobatsu_entry, "は同じ超抜式の引保師を選択してください")
  end
end
