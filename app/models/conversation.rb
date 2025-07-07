class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  
  validates :session_id, presence: true, uniqueness: true
  validates :expires_at, presence: true
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :recent, -> { order(last_message_at: :desc) }
  
  before_create :set_expires_at
  before_save :update_last_message_at, if: :will_save_change_to_updated_at?
  
  def expired?
    expires_at <= Time.current
  end
  
  def active?
    !expired?
  end
  
  private
  
  def set_expires_at
    self.expires_at ||= 7.days.from_now
  end
  
  def update_last_message_at
    self.last_message_at = Time.current if messages.any?
  end
end
