# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Admin Embedding Dashboard', type: :feature do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:regulation) { create(:regulation) }
  let!(:articles) { create_list(:article, 5, regulation: regulation) }

  before do
    # Login as admin
    visit login_path
    fill_in 'Email', with: admin_user.email
    fill_in 'Password', with: admin_user.password
    click_button 'Login'
  end

  scenario 'Admin can view embedding dashboard' do
    visit admin_embedding_dashboard_path

    expect(page).to have_content('임베딩 대시보드')
    expect(page).to have_content('전체 조문')
    expect(page).to have_content('임베딩 완료')
    expect(page).to have_content('임베딩 대기')
    expect(page).to have_content('완료율')
  end

  scenario 'Dashboard shows correct statistics' do
    # Add embedding to some articles
    articles.first(2).each do |article|
      article.update_columns(
        embedding: Array.new(1536, 0.1),
        embedding_updated_at: 1.hour.ago
      )
    end

    visit admin_embedding_dashboard_path

    expect(page).to have_content("#{articles.count}")  # Total articles
    expect(page).to have_content('2')  # Articles with embedding
    expect(page).to have_content('3')  # Articles without embedding
  end

  scenario 'Dashboard shows Sidekiq queue information' do
    visit admin_embedding_dashboard_path

    expect(page).to have_content('Sidekiq 큐 상태')
    expect(page).to have_content('처리된 작업')
    expect(page).to have_content('실패한 작업')
    expect(page).to have_content('대기 중인 작업')
  end

  scenario 'Dashboard shows recent embedding updates' do
    # Add recent embedding update
    articles.first.update_columns(
      embedding: Array.new(1536, 0.1),
      embedding_updated_at: 1.hour.ago
    )

    visit admin_embedding_dashboard_path

    expect(page).to have_content('최근 임베딩 업데이트')
    expect(page).to have_content("제#{articles.first.number}조")
  end

  scenario 'Dashboard has action buttons for embedding tasks' do
    visit admin_embedding_dashboard_path

    expect(page).to have_button('전체 생성')
    expect(page).to have_button('누락분 생성')
    expect(page).to have_button('수정분 업데이트')
    expect(page).to have_button('실패 작업 정리')
  end

  scenario 'Dashboard has link to Sidekiq Web UI' do
    visit admin_embedding_dashboard_path

    expect(page).to have_link('Sidekiq Web UI', href: '/sidekiq')
  end
end