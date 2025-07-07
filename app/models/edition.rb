class Edition < ApplicationRecord
  has_many :chapters, dependent: :destroy
  has_many :regulations, through: :chapters
  has_many :articles, through: :regulations
  
  validates :number, presence: true, uniqueness: true, inclusion: { in: 1..6 }
  validates :title, presence: true
  validates :sort_order, presence: true, uniqueness: true
  
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
  
  def full_title
    "Edition #{number}: #{title}"
  end
end