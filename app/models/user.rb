class User < ApplicationRecord
  belongs_to :region

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  def admin?
    admin
  end
end
