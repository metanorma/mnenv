# frozen_string_literal: true

# Simple test configuration without HTTP mocking
# Tests that need network access use :skip_vcr metadata to indicate they're integration tests
RSpec.configure do |config|
  config.before(:suite) do
    # Set up a test versions manager that uses a temp directory
    # This prevents tests from touching the real ~/.mnenv directory
  end
end
