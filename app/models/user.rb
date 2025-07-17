class User < ApplicationRecord
  has_paper_trail
  
  has_secure_password validations: false
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[user admin super_admin] }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?
  
  scope :active, -> { where.not(role: nil) }
  scope :users, -> { where(role: 'user') }
  scope :admins, -> { where(role: 'admin') }
  scope :super_admins, -> { where(role: 'super_admin') }
  
  def user?
    role == 'user'
  end
  
  def admin?
    role == 'admin'
  end
  
  def super_admin?
    role == 'super_admin'
  end
  
  # 비밀번호 강도 검증
  def password_strength_valid?
    return false unless password.present?
    
    # 최소 8자, 대소문자, 숫자, 특수문자 포함
    password.length >= 8 &&
      password.match?(/[a-z]/) &&
      password.match?(/[A-Z]/) &&
      password.match?(/\d/) &&
      password.match?(/[^a-zA-Z\d]/)
  end
  
  # 마지막 로그인 시간 업데이트
  def update_last_login!
    update_column(:last_login_at, Time.current)
  end
  
  # 인증 메서드 (이메일과 비밀번호로 로그인)
  def self.authenticate(email, password)
    user = find_by(email: email&.downcase)
    user&.authenticate(password) ? user : nil
  end
  
  # 비밀번호 재설정 관련 메서드 (향후 확장용)
  def generate_password_reset_token
    # 향후 password_reset_token, password_reset_sent_at 컬럼 추가 시 사용
    # self.password_reset_token = SecureRandom.urlsafe_base64
    # self.password_reset_sent_at = Time.current
    # save!
  end
  
  # 계정 잠금 관련 메서드 (향후 확장용)
  def increment_failed_attempts!
    # 향후 failed_attempts, locked_until 컬럼 추가 시 사용
    # self.failed_attempts = (failed_attempts || 0) + 1
    # self.locked_until = 30.minutes.from_now if failed_attempts >= 5
    # save!
  end
  
  def reset_failed_attempts!
    # 향후 확장용
    # update_columns(failed_attempts: 0, locked_until: nil)
  end
  
  def locked?
    # 향후 확장용
    # locked_until.present? && locked_until > Time.current
    false
  end
  
  private
  
  def password_required?
    password_digest.blank? || password.present?
  end
end