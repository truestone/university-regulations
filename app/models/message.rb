class Message < ApplicationRecord
  belongs_to :conversation
  
  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  validates :tokens_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }
  
  after_create :update_conversation_timestamp
  after_create :update_conversation_title, if: :user_message?
  
  def user_message?
    role == 'user'
  end
  
  def assistant_message?
    role == 'assistant'
  end
  
  private
  
  def update_conversation_timestamp
    conversation.update(last_message_at: created_at)
  end
  
  def update_conversation_title
    # 첫 번째 사용자 메시지인 경우에만 제목 업데이트
    if conversation.messages.user_messages.count == 1
      conversation.update_title_from_first_message!
    end
  end
end