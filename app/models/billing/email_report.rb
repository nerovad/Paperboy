# frozen_string_literal: true

module Billing
  class EmailReport
    TYPE_PATTERN = /\A(?:p)?([A-Z]{2,3})\d{4}-TC60-/i

    attr_reader :name, :files, :billing_type

    def self.all(root: ReportFile::ROOT)
      ReportFile.all(root: root).group_by { |file| file.path.basename(file.path.extname).to_s }
                                .map { |name, files| new(name: name, files: files) }
                                .sort_by(&:name)
    end

    def initialize(name:, files:)
      @name = name
      @files = files.sort_by(&:filename)
      @billing_type = name[TYPE_PATTERN, 1]&.upcase
    end

    def active_by_default?(active_types)
      billing_type.present? && active_types.include?(billing_type)
    end

    def filenames
      files.map(&:filename)
    end
  end
end
