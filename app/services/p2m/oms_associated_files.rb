# frozen_string_literal: true

require 'pathname'

module P2m
  class OmsAssociatedFiles
    ROOT = Pathname.new('/mnt/o/Outputs')
    OMS_NUMBER = '\d{8,9}'
    PATTERNS = [
      /\AMail\.dat_(#{OMS_NUMBER})\.zip\z/i,
      /\A(#{OMS_NUMBER})-.+\.csv\z/i,
      /\APresort Fields Export_(#{OMS_NUMBER})\.txt\z/i,
      /\AMoveResults_(#{OMS_NUMBER})\.txt\z/i,
      /\A(#{OMS_NUMBER})[-_].+\.pdf\z/i,
      /\A.+_(#{OMS_NUMBER})\.pdf\z/i
    ].freeze
    EXCLUDED_DIRECTORIES = %w[DataRunner FinalOutput].freeze

    def initialize(root: ROOT)
      @root = Pathname.new(root).expand_path
    end

    def call(directory:, oms_number:)
      validate_oms_number!(oms_number)
      path = resolve_directory(directory)
      path.children.filter_map do |file|
        match = file.file? && matching_name(file.basename.to_s)
        file.basename.to_s if match && match[1] == oms_number
      end.sort
    end

    def tray_labels(directory:, oms_number:)
      path = resolve_directory(directory)
      filename = call(directory: directory, oms_number: oms_number).find do |name|
        normalized_name = name.downcase
        normalized_name.end_with?('.pdf') && normalized_name.gsub(/[^a-z0-9]+/, ' ').include?('tray labels')
      end
      raise ArgumentError, 'Tray Labels PDF not found' unless filename

      path.join(filename)
    end

    def preview(directory:, oms_number:, filename:)
      raise ArgumentError, 'ZIP files cannot be previewed' if File.extname(filename.to_s).casecmp?('.zip')

      path = resolve_directory(directory)
      available_filename = call(directory: directory, oms_number: oms_number).find do |name|
        name == filename
      end
      raise ArgumentError, 'associated file not found' unless available_filename

      path.join(available_filename)
    end

    private

    attr_reader :root

    def validate_oms_number!(number)
      raise ArgumentError, 'invalid OMS number' unless number.to_s.match?(/\A#{OMS_NUMBER}\z/)
    end

    def resolve_directory(directory)
      path = root.join(directory.to_s).cleanpath
      relative = path.relative_path_from(root)
      first_directory = relative.each_filename.first
      invalid = first_directory == '..' || EXCLUDED_DIRECTORIES.include?(first_directory)
      raise ArgumentError, 'invalid OMS directory' if invalid
      raise ArgumentError, 'OMS directory not found' unless path.directory?

      path
    rescue ArgumentError
      raise ArgumentError, 'invalid OMS directory'
    end

    def matching_name(name)
      PATTERNS.filter_map { |pattern| name.match(pattern) }.first
    end
  end
end
