class Regulation < ApplicationRecord
  belongs_to :chapter
  has_many :articles, dependent: :destroy
  has_many :clauses, through: :articles

  validates :title, presence: true
  validates :regulation_code, presence: true, uniqueness: true
  validates :number, presence: true
  validates :sort_order, presence: true

  scope :by_chapter, ->(chapter) { where(chapter: chapter) }
  scope :ordered, -> { order(:sort_order) }

  def full_title
    "#{regulation_code} #{title}"
  end

  def chapter_title
    chapter&.title
  end

  def edition_title
    chapter&.edition&.title
  end
end