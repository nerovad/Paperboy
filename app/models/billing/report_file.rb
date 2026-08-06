# frozen_string_literal: true

module Billing
  class ReportFile
    ROOT = Rails.root.join('output/billing').freeze
    EXTENSIONS = %w[.pdf .xlsx].freeze

    def self.all(root: ROOT)
      return [] unless root.directory?

      root.children.filter_map do |path|
        new(path) if valid_path?(path)
      end.sort_by(&:modified_at).reverse
    end

    def self.find(filename, root: ROOT)
      raise ActiveRecord::RecordNotFound unless File.basename(filename) == filename

      path = root.join(filename)
      raise ActiveRecord::RecordNotFound unless valid_path?(path)

      new(path)
    end

    def self.valid_path?(path)
      path.file? && !path.symlink? && EXTENSIONS.include?(path.extname.downcase)
    end
    private_class_method :valid_path?

    def initialize(path)
      @path = path
    end

    attr_reader :path

    delegate :size, to: :path

    def filename
      path.basename.to_s
    end

    def modified_at
      path.mtime
    end

    def pdf?
      path.extname.casecmp('.pdf').zero?
    end

    def content_type
      pdf? ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end
  end
end
