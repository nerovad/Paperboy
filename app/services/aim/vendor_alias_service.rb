# frozen_string_literal: true

require 'fileutils'

module Aim
  class VendorAliasService
    NOTE_PREFIX = 'Learned from AIM vendor review'

    class AliasStoreError < StandardError; end

    class << self
      def official_names
        read_aliases.values.map { |name| name.to_s.squish }.reject(&:blank?).uniq.sort_by(&:downcase)
      end

      def learn!(extracted_name:, normalized_name:, learned_by:)
        extracted = normalize_vendor_text(extracted_name)
        normalized = normalize_vendor_text(normalized_name)
        raise ArgumentError, 'Extracted vendor name is required.' if extracted.blank?
        raise ArgumentError, 'Official vendor name is required.' if normalized.blank?

        with_alias_lock do |aliases|
          aliases[normalized] = normalized unless extracted.casecmp?(normalized)
          aliases[extracted] = normalized
        end

        Rails.logger.info("#{NOTE_PREFIX} by #{learned_by}: #{extracted} -> #{normalized}")
      end

      def alias_file_path
        configured_path = ENV.fetch('AIM_ALIAS_DB_FILE', nil).presence
        raise MissingConfiguration.for('AIM_ALIAS_DB_FILE', 'The AIM vendor alias store') if configured_path.nil?

        translated_path(configured_path)
      end

      private

      def read_aliases(path = alias_file_path)
        return {} unless path.exist?

        parsed = JSON.parse(path.read)
        return parsed if parsed.is_a?(Hash)

        raise AliasStoreError, "AIM vendor alias JSON must be an object: #{path}"
      rescue JSON::ParserError => e
        raise AliasStoreError, "AIM vendor alias JSON is invalid: #{e.message}"
      rescue SystemCallError => e
        raise AliasStoreError, "AIM vendor alias JSON could not be read: #{e.message}"
      end

      def with_alias_lock
        path = alias_file_path
        FileUtils.mkdir_p(path.dirname)

        File.open(lock_file_path(path), File::RDWR | File::CREAT, 0o644) do |lock_file|
          lock_file.flock(File::LOCK_EX)

          aliases = read_aliases(path)
          yield aliases
          write_aliases(path, aliases)
        ensure
          lock_file&.flock(File::LOCK_UN)
        end
      rescue SystemCallError => e
        raise AliasStoreError, "AIM vendor alias JSON could not be written: #{e.message}"
      end

      def write_aliases(path, aliases)
        temp_path = Pathname.new("#{path}.tmp-#{Process.pid}")
        temp_path.write("#{JSON.pretty_generate(aliases)}\n")
        File.rename(temp_path, path)
      ensure
        FileUtils.rm_f(temp_path) if temp_path&.exist?
      end

      def lock_file_path(path)
        "#{path}.lock"
      end

      # The worker install folder on the AIM share. AIM_ALIAS_DB_FILE is
      # normally a bare filename, and this is what it is resolved against.
      def program_dir
        configured = ENV.fetch('AIM_PROGRAM_DIR', nil).presence
        raise MissingConfiguration.for('AIM_PROGRAM_DIR', 'The AIM program folder') if configured.nil?

        Pathname.new(to_linux(configured))
      end

      def translated_path(path)
        normalized_path = to_linux(path)
        return Pathname.new(normalized_path) if normalized_path.include?('/')

        program_dir.join(normalized_path)
      end

      def to_linux(path)
        linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil).presence
        windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil).presence
        normalized_path = path.to_s

        normalized_path = normalized_path.gsub(windows_base, linux_base) if linux_base.present? && windows_base.present?
        normalized_path.tr('\\', '/')
      end

      def normalize_vendor_text(value)
        value.to_s.squish.presence
      end
    end
  end
end
