require 'rails_helper'

RSpec.describe Article, type: :model do
  describe 'associations' do
    it { should belong_to(:regulation) }
    it { should have_many(:clauses).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:sort_order) }
    it { should validate_numericality_of(:sort_order).only_integer.is_greater_than(0) }
  end

  describe 'scopes and methods' do
    let(:regulation) { create(:regulation) }
    let!(:article1) { create(:article, regulation: regulation, sort_order: 1) }
    let!(:article2) { create(:article, regulation: regulation, sort_order: 2) }

    it 'orders by sort_order by default' do
      expect(Article.all).to eq([article1, article2])
    end
  end

  describe 'embedding validation' do
    it 'validates embedding vector dimensions' do
      article = build(:article, embedding: Array.new(1536, 0.1))
      expect(article).to be_valid
    end

    it 'rejects invalid embedding dimensions' do
      article = build(:article, embedding: Array.new(100, 0.1))
      expect(article).not_to be_valid
      expect(article.errors[:embedding]).to include('must be a 1536-dimensional vector')
    end
  end
end
