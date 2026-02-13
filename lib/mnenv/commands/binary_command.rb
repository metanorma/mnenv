# frozen_string_literal: true

require 'thor'
require_relative '../binary/fetcher'
require_relative '../repository'

module Mnenv
  class BinaryCommand < Thor
    package_name 'mnenv binary'

    desc 'refresh', 'Fetch new binary versions not present locally'
    def refresh
      fetcher = Binary::Fetcher.new
      repo = BinaryRepository.new

      existing_versions = repo.all.map(&:version)
      releases = fetcher.fetch_all

      new_versions = releases.reject { |r| existing_versions.include?(r['version']) }

      if new_versions.empty?
        puts 'No new binary versions found.'
        return
      end

      puts "Found #{new_versions.size} new binary version(s):"
      new_versions.each { |v| puts "  #{v['version']}" }

      # Save to versions.yaml
      all_versions = existing_versions.map do |v|
        ver = repo.find(v)
        ver_to_hash(ver)
      end + new_versions

      save_versions(all_versions)
      puts 'Updated data/binary/versions.yaml'
    end

    desc 'revamp', 'Re-fetch all binary versions from GitHub'
    def revamp
      fetcher = Binary::Fetcher.new
      releases = fetcher.fetch_all

      if releases.empty?
        puts 'No binary versions found.'
        return
      end

      puts "Fetched #{releases.size} binary version(s)"

      # Sort by version (descending)
      sorted = releases.sort_by { |r| Gem::Version.new(r['version']) }.reverse

      save_versions(sorted)
      puts 'Updated data/binary/versions.yaml'
    end

    desc 'update VERSION', 'Update a specific binary version'
    def update(version)
      version = version.sub(/^v/, '')
      tag = "v#{version}"

      fetcher = Binary::Fetcher.new
      release = fetcher.fetch_by_tag(tag)

      unless release
        puts "Binary version #{version} not found."
        exit 1
      end

      puts "Updating binary version #{version}..."

      # Load existing versions
      repo = BinaryRepository.new
      existing = repo.all.reject { |v| v.version == version }
      all_versions = existing.map { |v| ver_to_hash(v) } + [release]

      save_versions(all_versions)
      puts 'Updated data/binary/versions.yaml'
    end

    desc 'list', 'List all available binary versions'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def list
      repo = BinaryRepository.new
      versions = repo.all

      case options[:format]
      when 'json'
        require_relative '../json_formatter'
        output = JsonFormatter.format_versions(versions)
        output['source'] = 'binary'
        puts JSON.pretty_generate(output)
      else
        puts "Binary versions (#{versions.size}):"
        versions.each do |v|
          published = v.published_at ? " (#{v.published_at.strftime('%Y-%m-%d')})" : ''
          assets_count = v.assets.size
          puts "  #{v.display_name}#{published} [#{assets_count} assets]"
        end
      end
    end

    private

    def ver_to_hash(ver)
      {
        'version' => ver.version,
        'published_at' => ver.published_at&.utc&.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'parsed_at' => ver.parsed_at&.utc&.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'tag_name' => "v#{ver.version}",
        'html_url' => ver.html_url,
        'platforms' => parse_assets_to_platforms(ver.assets)
      }
    end

    def parse_assets_to_platforms(assets)
      assets.map do |name|
        platform = parse_asset_name(name)
        next nil unless platform

        {
          'name' => platform[:os],
          'arch' => platform[:arch],
          'variant' => platform[:variant],
          'format' => platform[:format],
          'filename' => name
        }.compact
      end.compact
    end

    def parse_asset_name(name)
      return nil unless name =~ /^metanorma-(.+)/

      parts = Regexp.last_match(1).split('.')
      basename = parts.first
      format = parts.last

      return nil unless %w[tgz zip exe].include?(format)

      components = basename.split('-')

      case components
      in ['darwin', arch]
        { os: 'darwin', arch: arch, format: format }
      in ['linux', 'musl', arch]
        { os: 'linux', arch: arch, variant: 'musl', format: format }
      in ['linux', arch]
        { os: 'linux', arch: arch, format: format }
      in ['windows', arch]
        { os: 'windows', arch: arch, format: format }
      in ['macos', arch]
        { os: 'darwin', arch: arch, format: format }
      else
        { os: components.first, arch: components.last, format: format }
      end
    end

    def save_versions(versions)
      require 'yaml'
      require 'fileutils'

      data_dir = File.expand_path('data/binary')
      versions_file = File.join(data_dir, 'versions.yaml')

      # Sort versions by version number (descending)
      sorted = versions.sort_by { |v| Gem::Version.new(v['version']) }.reverse

      output = {
        'metadata' => {
          'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
          'source' => 'binary',
          'count' => sorted.size,
          'latest_version' => sorted.first&.dig('version')
        },
        'versions' => sorted
      }

      FileUtils.mkdir_p(data_dir)
      File.write(versions_file, output.to_yaml)
    end
  end
end
