# frozen_string_literal: true

require 'paint'

module Mnenv
  class Logger
    # Emojis for different log levels
    EMOJIS = {
      info: 'ℹ️',
      success: '✅',
      warning: '⚠️',
      error: '❌',
      debug: '🔍',
      pulling: '📥',
      extracting: '📦',
      skipping: '⏭️',
      cleaning: '🧹'
    }.freeze

    class << self
      def info(message)
        puts Paint["#{EMOJIS[:info]} #{message}", :cyan]
      end

      def success(message)
        puts Paint["#{EMOJIS[:success]} #{message}", :green]
      end

      def warning(message)
        warn Paint["#{EMOJIS[:warning]} WARNING: #{message}", :yellow]
      end

      def error(message)
        warn Paint["#{EMOJIS[:error]} ERROR: #{message}", :red, :bold]
      end

      # Only outputs when verbose mode is enabled
      def debug(message)
        return unless Cli.verbose?

        puts Paint["#{EMOJIS[:debug]} [DEBUG] #{message}", :magenta]
      end

      def pulling(version)
        puts Paint["#{EMOJIS[:pulling]} Pulling metanorma/metanorma:#{version}...", :blue]
      end

      def extracted(version, from: nil)
        message = "  #{EMOJIS[:extracting]} Extracted to v#{version}/"
        message += " (from #{from})" if from
        puts Paint[message, :green]
      end

      def skipping(version)
        puts Paint["  #{EMOJIS[:skipping]} Skipping v#{version}/ (already exists)", :yellow]
      end

      def header(message)
        puts "\n#{Paint["=== #{message} ===", :bold, :white]}\n"
      end

      def section(message)
        puts Paint["▸ #{message}", :cyan]
      end

      def sub(message)
        puts Paint["  • #{message}", :gray]
      end
    end
  end
end
