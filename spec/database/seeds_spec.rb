# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database Seeds', type: :model do
  before(:all) do
    # 시드 데이터 로드 (이미 로드되어 있다면 스킵)
    Rails.application.load_seed unless User.exists?
  end

  describe 'User seeds' do
    it 'creates admin users' do
      expect(User.where(role: 'super_admin')).to exist
      expect(User.where(role: 'admin')).to exist
    end

    it 'creates users with valid attributes' do
      User.all.each do |user|
        expect(user).to be_valid
        expect(user.email).to be_present
        expect(user.name).to be_present
        expect(user.role).to be_present
      end
    end

    it 'creates users with unique emails' do
      emails = User.pluck(:email)
      expect(emails.uniq.length).to eq(emails.length)
    end
  end

  describe 'Edition seeds' do
    it 'creates multiple editions' do
      expect(Edition.count).to be >= 1
    end

    it 'creates editions with valid attributes' do
      Edition.all.each do |edition|
        expect(edition).to be_valid
        expect(edition.title).to be_present
        expect(edition.sort_order).to be_present
        expect(edition.status).to be_present
      end
    end

    it 'creates editions with unique sort orders' do
      sort_orders = Edition.pluck(:sort_order)
      expect(sort_orders.uniq.length).to eq(sort_orders.length)
    end
  end

  describe 'Chapter seeds' do
    it 'creates chapters for editions' do
      expect(Chapter.count).to be >= 1
    end

    it 'creates chapters with valid attributes' do
      Chapter.all.each do |chapter|
        expect(chapter).to be_valid
        expect(chapter.title).to be_present
        expect(chapter.sort_order).to be_present
        expect(chapter.edition).to be_present
      end
    end

    it 'maintains chapter hierarchy' do
      Chapter.all.each do |chapter|
        expect(chapter.edition).to be_persisted
      end
    end
  end

  describe 'Regulation seeds' do
    it 'creates regulations for chapters' do
      expect(Regulation.count).to be >= 1
    end

    it 'creates regulations with valid attributes' do
      Regulation.all.each do |regulation|
        expect(regulation).to be_valid
        expect(regulation.title).to be_present
        expect(regulation.number).to be_present
        expect(regulation.regulation_code).to be_present
        expect(regulation.chapter).to be_present
      end
    end

    it 'creates regulations with unique codes' do
      codes = Regulation.pluck(:regulation_code)
      expect(codes.uniq.length).to eq(codes.length)
    end

    it 'maintains regulation hierarchy' do
      Regulation.all.each do |regulation|
        expect(regulation.chapter).to be_persisted
        expect(regulation.chapter.edition).to be_persisted
      end
    end
  end

  describe 'Article seeds' do
    it 'creates articles for regulations' do
      expect(Article.count).to be >= 1
    end

    it 'creates articles with valid attributes' do
      Article.all.each do |article|
        expect(article).to be_valid
        expect(article.title).to be_present
        expect(article.content).to be_present
        expect(article.sort_order).to be_present
        expect(article.regulation).to be_present
      end
    end

    it 'maintains article hierarchy' do
      Article.all.each do |article|
        expect(article.regulation).to be_persisted
        expect(article.regulation.chapter).to be_persisted
        expect(article.regulation.chapter.edition).to be_persisted
      end
    end
  end

  describe 'Clause seeds' do
    it 'creates clauses for articles' do
      expect(Clause.count).to be >= 1
    end

    it 'creates clauses with valid attributes' do
      Clause.all.each do |clause|
        expect(clause).to be_valid
        expect(clause.content).to be_present
        expect(clause.sort_order).to be_present
        expect(clause.article).to be_present
      end
    end

    it 'maintains clause hierarchy' do
      Clause.all.each do |clause|
        expect(clause.article).to be_persisted
        expect(clause.article.regulation).to be_persisted
      end
    end
  end

  describe 'AI Setting seeds' do
    it 'creates AI settings' do
      expect(AiSetting.count).to be >= 1
    end

    it 'creates AI settings with valid attributes' do
      AiSetting.all.each do |setting|
        expect(setting).to be_valid
        expect(setting.provider).to be_present
        expect(setting.model_id).to be_present
      end
    end

    it 'creates settings for different providers' do
      providers = AiSetting.pluck(:provider).uniq
      expect(providers.length).to be >= 2
    end
  end

  describe 'Conversation seeds' do
    it 'creates conversations' do
      expect(Conversation.count).to be >= 1
    end

    it 'creates conversations with valid attributes' do
      Conversation.all.each do |conversation|
        expect(conversation).to be_valid
        expect(conversation.title).to be_present
        expect(conversation.user).to be_present
      end
    end
  end

  describe 'Message seeds' do
    it 'creates messages for conversations' do
      expect(Message.count).to be >= 1
    end

    it 'creates messages with valid attributes' do
      Message.all.each do |message|
        expect(message).to be_valid
        expect(message.content).to be_present
        expect(message.role).to be_present
        expect(message.conversation).to be_present
      end
    end

    it 'maintains message hierarchy' do
      Message.all.each do |message|
        expect(message.conversation).to be_persisted
        expect(message.conversation.user).to be_persisted
      end
    end
  end

  describe 'Data integrity' do
    it 'maintains referential integrity' do
      # 모든 외래키 관계가 유효한지 확인
      expect { 
        User.includes(:conversations).all.each(&:conversations)
        Edition.includes(:chapters).all.each(&:chapters)
        Chapter.includes(:regulations).all.each(&:regulations)
        Regulation.includes(:articles).all.each(&:articles)
        Article.includes(:clauses).all.each(&:clauses)
        Conversation.includes(:messages).all.each(&:messages)
      }.not_to raise_error
    end

    it 'has consistent sort orders' do
      # 각 계층에서 sort_order가 연속적인지 확인
      Edition.all.each do |edition|
        sort_orders = edition.chapters.pluck(:sort_order).sort
        expect(sort_orders).to eq((1..sort_orders.length).to_a) if sort_orders.any?
      end
    end
  end
end