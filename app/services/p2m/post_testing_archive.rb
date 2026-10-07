# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pathname'
require 'tempfile'
require_relative 'paths'

module P2m
  class PostTestingArchive
    START_DATE = Date.new(2026, 7, 1)
    END_DATE = Date.new(2026, 9, 30)
    REPORT_NAME = 'p2m_post_testing_archive.json'
    OMS_NUMBER = /\A\d{8,9}\z/

    def initialize(report_path: nil, processed_root: nil, source_root: nil, search: nil)
      @report_path = Pathname.new(report_path || Paths::DATA_RUNNER_ROOT.join(REPORT_NAME))
      @processed_root = Pathname.new(processed_root || local_processed_root).expand_path
      @source_root = Pathname.new(source_root || Paths::DATA_RUNNER_ROOT.parent).expand_path
      @search = search
    end

    def preview
      find_jobs.map { |job| present(job) }
    end

    def move(oms_number)
      number = oms_number.to_s
      raise ArgumentError, 'invalid OMS number' unless number.match?(OMS_NUMBER)

      job = stored_jobs.find { |row| row.fetch('oms_number') == number }
      raise ArgumentError, 'Reload Post Testing Archive before moving this OMS.' unless job

      files = Array(job.fetch('files')).map { |path| Pathname.new(path) }
      Relocation.new(processed_root, source_root).call(number, files)
    end

    private

    attr_reader :report_path, :processed_root, :source_root, :search

    def find_jobs
      return searched_jobs if search

      PrintAndInsertingDone.historical_jobs(
        start_date: START_DATE, end_date: END_DATE, report_path: report_path
      )
    end

    def searched_jobs
      jobs = Array(search.call(START_DATE, END_DATE))
      write_report(jobs)
      jobs
    end

    def present(job)
      files = Array(job.fetch('files'))
      {
        'oms_number' => job.fetch('oms_number'),
        'mail_date' => job.fetch('mail_date'),
        'status' => job.fetch('status'),
        'detail' => job.fetch('detail'),
        'files' => files.map { |path| File.basename(path) }.sort,
        'count' => files.size
      }
    end

    def stored_jobs
      raise ArgumentError, 'Reload Post Testing Archive before moving this OMS.' unless report_path.file?

      JSON.parse(report_path.read).fetch('rows')
    end

    def write_report(jobs)
      FileUtils.mkdir_p(report_path.dirname)
      payload = JSON.generate(
        'start_date' => START_DATE.iso8601, 'end_date' => END_DATE.iso8601, 'rows' => jobs
      )
      Tempfile.create(['p2m-post-testing-archive', '.json'], report_path.dirname.to_s) do |temp|
        temp.write(payload)
        temp.flush
        FileUtils.mv(temp.path, report_path)
      end
    end

    def local_processed_root
      store = Paths.processed_store
      raise ArgumentError, 'Processed archive is only available for a local directory.' unless
        store.is_a?(Paperboy::FileStore::Local)

      store.path
    end

    # Moves one OMS number's files into Processed/<oms number>.
    class Relocation
      def initialize(processed_root, source_root)
        @processed_root = processed_root
        @source_root = source_root
      end

      def call(number, files)
        processed_root.mkpath
        existing = files.select(&:file?)
        existing.each { |path| assert_source!(number, path) }
        move_files(number, existing.sort)
      end

      private

      attr_reader :processed_root, :source_root

      def move_files(number, files)
        moved = []
        removed = []
        files.each do |path|
          outcome = relocate_file(number, path)
          return stopped(number, path, moved, removed) if outcome == :conflict

          moved << path.basename.to_s if outcome == :moved
          removed << path.basename.to_s if outcome == :removed
        end
        success(number, moved, removed)
      end

      def relocate_file(number, source)
        destination = destination_for(number, source)
        destination.dirname.mkpath
        return conflict_or_remove(source, destination) if destination.file?
        raise ArgumentError, "archive destination is not a file: #{destination.basename}" if destination.exist?

        FileUtils.mv(source.to_s, destination.to_s)
        :moved
      end

      def conflict_or_remove(source, destination)
        return :conflict unless FileUtils.compare_file(source, destination)

        FileUtils.rm_f(source)
        :removed
      end

      def assert_source!(number, source)
        real = source.realpath
        raise ArgumentError, 'refusing to move a file outside the historical tree' unless inside_historical_tree?(real)

        match = OmsAssociatedFiles::PATTERNS.filter_map { |pattern| real.basename.to_s.match(pattern) }.first
        return if match && match[1] == number

        raise ArgumentError, 'refusing to move a file that does not belong to this OMS'
      end

      def inside_historical_tree?(real)
        root = source_root.realpath
        processed = processed_root.realpath
        real.to_s.start_with?("#{root}/") && !real.to_s.start_with?("#{processed}/") && real.to_s != processed.to_s
      end

      def destination_for(number, source)
        destination = processed_root.join(number, source.basename.to_s).cleanpath
        raise ArgumentError, 'invalid archive destination' unless destination.to_s.start_with?("#{processed_root}/")

        destination
      end

      def success(number, moved, removed)
        {
          'oms_number' => number, 'error' => false, 'moved' => moved, 'removed' => removed,
          'message' => success_message(number, moved, removed)
        }
      end

      def success_message(number, moved, removed)
        return "No historical files remain for #{number}." if moved.empty? && removed.empty?
        return moved_message(number, moved) if removed.empty?
        return removed_message(number, removed) if moved.empty?

        "#{moved_message(number, moved).sub('.', '')} and #{removed_message(number, removed).sub(/\ARemoved/, 'removed')}"
      end

      def moved_message(number, moved)
        "Moved #{moved.size} #{'file'.pluralize(moved.size)} for #{number}."
      end

      def removed_message(number, removed)
        "Removed #{removed.size} matching historical #{'file'.pluralize(removed.size)} for #{number}."
      end

      def stopped(number, path, moved, removed)
        {
          'oms_number' => number, 'error' => true, 'moved' => moved, 'removed' => removed,
          'message' => "Stopped #{number} at #{path.basename} because Processed has different contents."
        }
      end
    end
  end
end
