class Fellowship < ApplicationRecord
  AVAILABLE_NAMES = [
    "大江戸", "お台場", "羽田", "かながわ", "富士山", "駿天",
    "埼玉", "千葉", "山梨", "聖明王院", "大仏殿"
  ].freeze

  belongs_to :region
  has_many :chobatsu_reports, dependent: :restrict_with_exception
  has_many :ceremony_schedules, dependent: :destroy
  has_many :ceremony_schedule_allocations, dependent: :destroy
  has_many :users, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :enabled, -> { where(enabled: true) }
  scope :display_sorted, -> { order(:display_order, :id) }
  scope :available, -> { where(name: AVAILABLE_NAMES).in_order_of(:name, AVAILABLE_NAMES) }

  validates :name, presence: true, uniqueness: true
  validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true
  validates :display_order, numericality: { only_integer: true, allow_nil: true }
end
