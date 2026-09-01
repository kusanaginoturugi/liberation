class Fellowship < ApplicationRecord
  AVAILABLE_NAMES = [
    "大江戸", "お台場", "羽田", "かながわ", "富士山", "駿天",
    "埼玉", "千葉", "山梨", "聖明王院", "大仏殿"
  ].freeze

  ALTAR_COUNTS = {
    "大江戸" => 3,
    "お台場" => 6,
    "羽田" => 11,
    "かながわ" => 15,
    "富士山" => 4,
    "駿天" => 3,
    "埼玉" => 8,
    "千葉" => 15,
    "山梨" => 5
  }.freeze

  belongs_to :region
  has_many :chobatsu_reports, dependent: :restrict_with_exception
  has_many :ceremony_schedules, dependent: :destroy
  has_many :ceremony_schedule_allocations, dependent: :destroy
  has_many :users, dependent: :nullify

  before_validation :assign_default_altar_count, on: :create

  scope :active, -> { where(active: true) }
  scope :enabled, -> { where(enabled: true) }
  scope :display_sorted, -> { order(:display_order, :id) }
  scope :available, -> { where(name: AVAILABLE_NAMES).in_order_of(:name, AVAILABLE_NAMES) }

  validates :name, presence: true, uniqueness: true
  validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true
  validates :display_order, numericality: { only_integer: true, allow_nil: true }
  validates :altar_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def assign_default_altar_count
    self.altar_count = ALTAR_COUNTS.fetch(name, 0)
  end
end
