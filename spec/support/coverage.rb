# frozen_string_literal: true

require 'simplecov'
require 'simplecov-lcov'

# Configure SimpleCov
SimpleCov.start 'rails' do
  # Output formats
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])

  # Coverage thresholds
  minimum_coverage 90
  minimum_coverage_by_file 80

  # Directories to include
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Workers', 'app/workers'
  add_group 'Validators', 'app/validators'
  add_group 'Helpers', 'app/helpers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Channels', 'app/channels'

  # Files to exclude from coverage
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/'
  add_filter '/bin/'
  add_filter '/tmp/'
  add_filter '/log/'
  add_filter '/public/'
  add_filter '/storage/'
  add_filter 'app/channels/application_cable/'
  add_filter 'app/mailers/application_mailer.rb'
  add_filter 'app/models/application_record.rb'
  add_filter 'app/controllers/application_controller.rb'

  # Track files even if they're not loaded during tests
  track_files '{app,lib}/**/*.rb'

  # Merge results from different test runs
  merge_timeout 3600

  # Enable branch coverage
  enable_coverage :branch

  # Custom coverage tracking
  at_exit do
    if SimpleCov.result.covered_percent < minimum_coverage
      puts "\n❌ Coverage is below minimum threshold of #{minimum_coverage}%"
      puts "Current coverage: #{SimpleCov.result.covered_percent.round(2)}%"
      exit(1) if ENV['FAIL_ON_LOW_COVERAGE'] == 'true'
    else
      puts "\n✅ Coverage threshold met: #{SimpleCov.result.covered_percent.round(2)}%"
    end
  end
end

# Coverage reporting for CI
if ENV['CI']
  SimpleCov.coverage_dir 'tmp/coverage'
  SimpleCov.command_name "RSpec-#{ENV['TEST_GROUP'] || 'all'}"
  
  # Generate LCOV format for external tools
  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = 'tmp/coverage/lcov.info'
  end
end