class Regulation < ApplicationRecord
  belongs_to :chapter
  has_many :articles, dependent: :destroy
  has_many :clauses, through: :articles
  
  validates :number, presence: true
  validates :title, presence: true
  validates :regulation_code, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[active inactive abolished] }
  validates :sort_order, presence: true
  validates :number, uniqueness: { scope: :chapter_id }
  validates :sort_order, uniqueness: { scope: :chapter_id }
  
  scope :active, -> { where(is_active: true, status: 'active') }
  scope :ordered, -> { order(:sort_order) }
  scope :by_status, ->(status) { where(status: status) }
  
  def full_title
    "Regulation #{regulation_code}: #{title}"
  end
  
  def abolished?
    status == 'abolished'
  end
end
