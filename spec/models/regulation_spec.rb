require 'rails_helper'

RSpec.describe Regulation, type: :model do
  describe 'associations' do
    it { should belong_to(:chapter) }
    it { should have_many(:articles).dependent(:destroy) }
    it { should have_many(:clauses).through(:articles) }
  end

  describe 'validations' do
    it 'validates presence of required fields' do
      regulation = Regulation.new
      expect(regulation).not_to be_valid
      expect(regulation.errors[:number]).to include("can't be blank")
      expect(regulation.errors[:title]).to include("can't be blank")
      expect(regulation.errors[:regulation_code]).to include("can't be blank")
    end

    it 'validates regulation_code format' do
      regulation = Regulation.new(regulation_code: 'invalid-format')
      expect(regulation).not_to be_valid
      expect(regulation.errors[:regulation_code]).to include('must be in format X-Y-Z (edition-chapter-regulation)')
    end

    it 'validates edition number in regulation_code' do
      regulation = Regulation.new(regulation_code: '7-1-1')
      expect(regulation).not_to be_valid
      expect(regulation.errors[:regulation_code]).to include('edition number must be between 1 and 6')
    end
  end

  describe 'methods' do
    let(:regulation) { Regulation.new(status: 'abolished') }

    it 'identifies abolished status' do
      expect(regulation.abolished?).to be true
    end
  end
end
