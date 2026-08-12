# frozen_string_literal: true

require 'fileutils'

module Billing
  class ReportArchiver
    class FileExists < StandardError; end

    def initialize(filenames:, destination:, root: ReportFile::ROOT)
      @filenames = filenames
      @destination = destination
      @root = root
    end

    def call
      files = filenames.map { |filename| ReportFile.find(filename, root: root) }
      ensure_available!(files)
      files.each { |file| FileUtils.mv(file.path, destination.path.join(file.filename)) }
      files.length
    end

    private

    attr_reader :filenames, :destination, :root

    def ensure_available!(files)
      collision = files.find { |file| destination.path.join(file.filename).exist? }
      return unless collision

      raise FileExists, "#{collision.filename} already exists in the archive location"
    end
  end
end
