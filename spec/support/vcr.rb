# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

# Test configuration with mock VersionsManager
# This prevents tests from touching the real ~/.mnenv directory
# and avoids git operations that can hang on Windows
RSpec.configure do |config|
  config.before(:suite) do
    # Create a temp directory for test data
    @test_data_dir = Dir.mktmpdir('mnenv-test')

    # Create a mock versions data directory structure
    gemfile_dir = File.join(@test_data_dir, 'gemfile')
    FileUtils.mkdir_p(gemfile_dir)

    # Create a minimal versions.yaml for gemfile tests
    versions_file = File.join(gemfile_dir, 'versions.yaml')
    test_versions = {
      'metadata' => {
        'source' => 'gemfile',
        'count' => 2,
        'latest_version' => '1.14.4'
      },
      'versions' => [
        { 'version' => '1.14.3', 'parsed_at' => '2024-01-01T00:00:00Z' },
        { 'version' => '1.14.4', 'parsed_at' => '2024-01-02T00:00:00Z' }
      ]
    }
    File.write(versions_file, test_versions.to_yaml)

    # Create a mock VersionsManager that returns the test data directory
    mock_manager = Class.new do
      attr_reader :data_path

      def initialize(data_path)
        @data_path = data_path
      end

      def ensure_versions_data(update: false)
        @data_path
      end

      def cloned?
        true
      end

      def stale?
        false
      end

      def update
        @data_path
      end
    end.new(@test_data_dir)

    # Set the mock manager as the default
    Mnenv::Repository.versions_manager = mock_manager
  end

  config.after(:suite) do
    # Clean up test data directory
    FileUtils.rm_rf(@test_data_dir) if @test_data_dir && Dir.exist?(@test_data_dir)
  end
end
