class Chapter < ApplicationRecord
  has_paper_trail
  
  belongs_to :edition
  has_many :regulations, dependent: :destroy
  has_many :articles, through: :regulations
  
  validates :number, presence: true
  validates :title, presence: true
  validates :sort_order, presence: true
  validates :number, uniqueness: { scope: :edition_id }
  validates :sort_order, uniqueness: { scope: :edition_id }
  
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
  
  def full_title
    "Chapter #{number}: #{title}"
  end
  
  def code
    "#{edition.number}-#{number}"
  end
end
