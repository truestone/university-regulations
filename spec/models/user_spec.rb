require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'validates presence of required fields' do
      user = User.new
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
      expect(user.errors[:name]).to include("can't be blank")
      expect(user.errors[:role]).to include("can't be blank")
    end

    it 'validates email format' do
      user = User.new(email: 'invalid-email', name: 'Test', role: 'admin', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'validates role inclusion' do
      user = User.new(email: 'test@example.com', name: 'Test', role: 'invalid_role', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include('is not included in the list')
    end
  end

  describe 'scopes and methods' do
    let(:admin) { User.new(role: 'admin') }
    let(:super_admin) { User.new(role: 'super_admin') }

    it 'identifies roles correctly' do
      expect(admin.admin?).to be true
      expect(admin.super_admin?).to be false
      expect(super_admin.super_admin?).to be true
      expect(super_admin.admin?).to be false
    end
  end
end
