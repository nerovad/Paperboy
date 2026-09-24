# frozen_string_literal: true

require 'open3'

module Paperboy
  module Version
    VERSION_FILE = Rails.root.join('VERSION')
    BASE = File.read(VERSION_FILE).strip.freeze

    class << self
      def to_s
        return ENV['PAPERBOY_VERSION'].strip if ENV['PAPERBOY_VERSION'].to_s.strip != ''

        [BASE, commit].compact.join('-')
      end

      def tag
        "v#{self}"
      end

      private

      def commit
        ENV['PAPERBOY_COMMIT'].presence || git_commit
      end

      def git_commit
        return unless Rails.root.join('.git').exist?

        output, status = Open3.capture2('git', '-C', Rails.root.to_s,
                                        'rev-parse', '--short=9', 'HEAD')
        output.strip.presence if status.success?
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
