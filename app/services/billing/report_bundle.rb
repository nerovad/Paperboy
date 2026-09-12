# frozen_string_literal: true

require 'zip'

module Billing
  class ReportBundle
    def initialize(artifacts)
      @artifacts = artifacts
    end

    def call
      Zip::OutputStream.write_buffer do |zip|
        artifacts.each do |artifact|
          write(zip, artifact.pdf_name, artifact.pdf_data)
          write(zip, artifact.overlay_pdf_name, artifact.overlay_pdf_data)
          write(zip, artifact.xlsx_name, artifact.xlsx_data)
        end
      end.string
    end

    private

    attr_reader :artifacts

    def write(zip, name, data)
      return if name.blank? || data.blank?

      zip.put_next_entry(File.basename(name))
      zip.write(data)
    end
  end
end
