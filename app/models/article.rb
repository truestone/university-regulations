class Article < ApplicationRecord
  has_paper_trail
  
  belongs_to :regulation
  has_many :clauses, dependent: :destroy
  
  # Rich text content using Action Text
  has_rich_text :rich_content
  
  validates :number, presence: true
  validates :title, presence: true
  validates :content, presence: true
  validates :sort_order, presence: true
  validates :number, uniqueness: { scope: :regulation_id }
  validates :sort_order, uniqueness: { scope: :regulation_id }
  validates :embedding, embedding: { dimensions: 1536, allow_blank: true }
  
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
  scope :with_embedding, -> { where.not(embedding: [nil, '']) }
  
  def full_title
    "Article #{number}: #{title}"
  end
  
  def has_embedding?
    embedding.present?
  end
end
