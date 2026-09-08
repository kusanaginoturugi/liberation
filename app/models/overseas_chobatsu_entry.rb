class OverseasChobatsuEntry < ApplicationRecord
  belongs_to :event
  belongs_to :fellowship
  has_many :overseas_chobatsu_assignments, dependent: :destroy

  before_validation :assign_input_order, on: :create

  validates :assistant_name, presence: true

  private

  def assign_input_order
    self.input_order ||= self.class.where(event_id:).maximum(:input_order).to_i + 1
  end
end
