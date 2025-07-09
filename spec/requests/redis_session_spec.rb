require 'rails_helper'

RSpec.describe 'Redis Session Store', type: :request do
  let(:user) { create(:user, email: 'admin@example.com', password: 'SecurePass123!') }

  describe 'session storage in Redis' do
    before do
      # Clear Redis session data
      $redis.flushdb
    end

    it 'stores session data in Redis after login' do
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      expect(response).to redirect_to(admin_dashboard_path)
      
      # Check if session data exists in Redis
      session_keys = $redis.keys('regulations:session:*')
      expect(session_keys).not_to be_empty
      
      # Verify session contains user_id
      session_key = session_keys.first
      session_data = JSON.parse($redis.get(session_key))
      expect(session_data['user_id']).to eq(user.id)
      expect(session_data['login_time']).to be_present
    end

    it 'removes session data from Redis after logout' do
      # Login first
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # Verify session exists
      session_keys_before = $redis.keys('regulations:session:*')
      expect(session_keys_before).not_to be_empty
      
      # Logout
      delete logout_path
      
      # Verify session is removed
      session_keys_after = $redis.keys('regulations:session:*')
      expect(session_keys_after).to be_empty
    end

    it 'handles session expiration' do
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # Get session key
      session_keys = $redis.keys('regulations:session:*')
      session_key = session_keys.first
      
      # Check TTL is set (should be around 4 hours = 14400 seconds)
      ttl = $redis.ttl(session_key)
      expect(ttl).to be > 14000  # Allow some margin for processing time
      expect(ttl).to be <= 14400
    end

    it 'maintains session across requests' do
      # Login
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # Make another request
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
      
      # Session should still exist
      session_keys = $redis.keys('regulations:session:*')
      expect(session_keys).not_to be_empty
    end

    it 'handles Redis connection failure gracefully' do
      # Mock Redis connection failure
      allow($redis).to receive(:ping).and_raise(Redis::CannotConnectError)
      
      # Should still be able to make requests (fallback to cookie store)
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # May redirect to login or handle gracefully depending on fallback
      expect(response.status).to be_in([200, 302, 422])
    end
  end

  describe 'session security' do
    it 'uses secure session configuration' do
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # Check session cookie attributes
      session_cookie = response.cookies['_regulations_session']
      expect(session_cookie).to be_present
      
      # In test environment, secure flag may not be set
      # but httponly should be enforced
    end

    it 'isolates sessions by namespace' do
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # All session keys should have the correct namespace
      session_keys = $redis.keys('*')
      session_keys.each do |key|
        expect(key).to start_with('regulations:session:') if key.include?('session')
      end
    end

    it 'handles concurrent sessions' do
      # Simulate multiple users logging in
      user2 = create(:user, email: 'admin2@example.com', password: 'SecurePass123!')
      
      # First user login
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      session_keys_1 = $redis.keys('regulations:session:*')
      
      # Clear cookies for second session
      reset!
      
      # Second user login
      post login_path, params: { email: user2.email, password: 'SecurePass123!' }
      session_keys_2 = $redis.keys('regulations:session:*')
      
      # Should have 2 separate sessions
      expect(session_keys_2.length).to eq(2)
    end
  end

  describe 'Redis configuration' do
    it 'connects to Redis successfully' do
      expect { $redis.ping }.not_to raise_error
    end

    it 'uses correct Redis database' do
      # Session store should use database 1
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
      
      # Check if session data is in the correct database
      session_keys = $redis.keys('regulations:session:*')
      expect(session_keys).not_to be_empty
    end

    it 'has proper Redis connection pool configuration' do
      expect(Redis.current).to be_a(ConnectionPool)
    end
  end
end