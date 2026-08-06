# frozen_string_literal: true

require 'fileutils'

module Billing
  class ReportWriter
    ROOT = Rails.root.join('output/billing').freeze

    def initialize(artifacts, root: ROOT)
      @artifacts = artifacts
      @root = root
    end

    def call
      FileUtils.mkdir_p(root)
      artifacts.each do |artifact|
        write(artifact.pdf_name, artifact.pdf_data)
        write(artifact.xlsx_name, artifact.xlsx_data)
      end
    end

    private

    attr_reader :artifacts, :root

    def write(name, data)
      root.join(File.basename(name)).binwrite(data)
    end
  end
end
