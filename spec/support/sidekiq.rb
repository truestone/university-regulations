# frozen_string_literal: true

require 'sidekiq/testing'

RSpec.configure do |config|
  config.before(:each) do
    # Clear all Sidekiq jobs before each test
    Sidekiq::Worker.clear_all
  end

  config.around(:each, :sidekiq_inline) do |example|
    # Run jobs inline for specific tests
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  config.around(:each, :sidekiq_fake) do |example|
    # Use fake mode (default) for specific tests
    Sidekiq::Testing.fake! do
      example.run
    end
  end

  # Default to fake mode
  config.before(:suite) do
    Sidekiq::Testing.fake!
  end
end