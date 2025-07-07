class User < ApplicationRecord
  has_secure_password
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin super_admin] }
  
  scope :active, -> { where.not(role: nil) }
  scope :admins, -> { where(role: 'admin') }
  scope :super_admins, -> { where(role: 'super_admin') }
  
  def admin?
    role == 'admin'
  end
  
  def super_admin?
    role == 'super_admin'
  end
end
