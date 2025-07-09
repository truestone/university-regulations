require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'password authentication' do
    let(:user) { build(:user, password: 'SecurePass123!', password_confirmation: 'SecurePass123!') }

    describe 'password validation' do
      it 'requires password presence for new users' do
        user.password = nil
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'requires minimum password length' do
        user.password = 'short'
        user.password_confirmation = 'short'
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 8 characters)')
      end

      it 'requires password confirmation' do
        user.password_confirmation = 'different'
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("doesn't match Password")
      end

      it 'accepts valid password' do
        expect(user).to be_valid
      end
    end

    describe 'password strength validation' do
      it 'validates strong password' do
        user.password = 'StrongPass123!'
        expect(user.password_strength_valid?).to be true
      end

      it 'rejects weak passwords' do
        weak_passwords = [
          'password',      # no uppercase, numbers, special chars
          'PASSWORD',      # no lowercase, numbers, special chars
          'Password',      # no numbers, special chars
          'Password123',   # no special chars
          'Pass123!',      # too short
          '12345678'       # no letters
        ]

        weak_passwords.each do |weak_password|
          user.password = weak_password
          expect(user.password_strength_valid?).to be false, "Expected '#{weak_password}' to be invalid"
        end
      end
    end

    describe 'authentication' do
      before { user.save! }

      it 'authenticates with correct password' do
        authenticated_user = User.authenticate(user.email, 'SecurePass123!')
        expect(authenticated_user).to eq(user)
      end

      it 'fails authentication with wrong password' do
        authenticated_user = User.authenticate(user.email, 'wrongpassword')
        expect(authenticated_user).to be_nil
      end

      it 'fails authentication with non-existent email' do
        authenticated_user = User.authenticate('nonexistent@example.com', 'SecurePass123!')
        expect(authenticated_user).to be_nil
      end

      it 'handles case-insensitive email authentication' do
        authenticated_user = User.authenticate(user.email.upcase, 'SecurePass123!')
        expect(authenticated_user).to eq(user)
      end
    end

    describe 'last login tracking' do
      before { user.save! }

      it 'updates last login time' do
        expect { user.update_last_login! }.to change { user.reload.last_login_at }
      end

      it 'sets last login time to current time' do
        freeze_time do
          user.update_last_login!
          expect(user.reload.last_login_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    describe 'password reset functionality' do
      before { user.save! }

      it 'has password reset methods defined' do
        expect(user).to respond_to(:generate_password_reset_token)
        expect(user).to respond_to(:increment_failed_attempts!)
        expect(user).to respond_to(:reset_failed_attempts!)
        expect(user).to respond_to(:locked?)
      end

      it 'is not locked by default' do
        expect(user.locked?).to be false
      end
    end

    describe 'bcrypt integration' do
      before { user.save! }

      it 'stores password as bcrypt hash' do
        expect(user.password_digest).to be_present
        expect(user.password_digest).not_to eq('SecurePass123!')
        expect(user.password_digest).to start_with('$2a$')
      end

      it 'authenticates using bcrypt' do
        expect(user.authenticate('SecurePass123!')).to eq(user)
        expect(user.authenticate('wrongpassword')).to be false
      end
    end

    describe 'password update' do
      before { user.save! }

      it 'allows password update' do
        expect(user.update(password: 'NewSecure456!', password_confirmation: 'NewSecure456!')).to be true
        expect(user.authenticate('NewSecure456!')).to eq(user)
        expect(user.authenticate('SecurePass123!')).to be false
      end

      it 'does not require password for other updates' do
        expect(user.update(name: 'New Name')).to be true
        expect(user.reload.name).to eq('New Name')
      end
    end
  end
end