# frozen_string_literal: true

require 'fileutils'

module Billing
  class ReportWriter
    ROOT = Rails.root.join('output/billing').freeze

    def initialize(artifacts, root: ROOT, replace_types: [])
      @artifacts = artifacts
      @root = root
      @replace_types = replace_types.to_set
    end

    def call
      FileUtils.mkdir_p(root)
      remove_replaced_reports
      artifacts.each do |artifact|
        write(artifact.pdf_name, artifact.pdf_data)
        write(artifact.overlay_pdf_name, artifact.overlay_pdf_data)
        write(artifact.xlsx_name, artifact.xlsx_data)
      end
    end

    private

    attr_reader :artifacts, :root, :replace_types

    def remove_replaced_reports
      EmailReport.all(root: root).each do |report|
        next unless replace_types.include?(report.billing_type)

        report.files.each { |file| FileUtils.rm_f(file.path) }
      end
    end

    def write(name, data)
      return if name.blank? || data.blank?

      root.join(File.basename(name)).binwrite(data)
    end
  end
end
