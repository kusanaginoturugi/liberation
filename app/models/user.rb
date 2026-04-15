class User < ApplicationRecord
  belongs_to :region
  has_many :chobatsu_reports, dependent: :nullify

  has_secure_password
  before_validation :assign_login_id, on: :create

  normalizes :email, with: ->(email) { normalize_email(email) }

  validates :login_id, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  def self.normalize_email(email)
    return if email.nil?

    email.to_s.unicode_normalize(:nfkc).gsub(/\s+/, "").downcase
  end

  def admin?
    admin
  end

  def self.next_login_id
    (maximum(:id).to_i + 1).to_s
  end

  private

  def assign_login_id
    self.login_id = self.class.next_login_id if login_id.blank?
  end
end
