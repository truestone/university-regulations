class Clause < ApplicationRecord
  has_paper_trail
  
  belongs_to :article
  
  validates :number, presence: true
  validates :content, presence: true
  validates :clause_type, presence: true, inclusion: { in: %w[paragraph subparagraph item subitem] }
  validates :sort_order, presence: true
  validates :number, uniqueness: { scope: :article_id }
  validates :sort_order, uniqueness: { scope: :article_id }
  
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
  scope :by_type, ->(type) { where(clause_type: type) }
  
  def full_title
    "Clause #{number} (#{clause_type})"
  end
end
