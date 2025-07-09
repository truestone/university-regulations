require 'rails_helper'

RSpec.describe Chapter, type: :model do
  describe 'associations' do
    it { should belong_to(:edition) }
    it { should have_many(:regulations).dependent(:destroy) }
    it { should have_many(:articles).through(:regulations) }
    it { should have_many(:clauses).through(:articles) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:sort_order) }
    it { should validate_numericality_of(:sort_order).only_integer.is_greater_than(0) }
  end

  describe 'scopes and methods' do
    let(:edition) { create(:edition) }
    let!(:chapter1) { create(:chapter, edition: edition, sort_order: 1) }
    let!(:chapter2) { create(:chapter, edition: edition, sort_order: 2) }

    it 'orders by sort_order by default' do
      expect(Chapter.all).to eq([chapter1, chapter2])
    end
  end
end
