# frozen_string_literal: true

require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    # Allow GitHub API for tests that need real network access
    # These tests should use :skip_webmock metadata
  end

  config.around(:each, :skip_webmock) do |example|
    WebMock.allow_net_connect!
    example.run
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
