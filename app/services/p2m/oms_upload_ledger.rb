# frozen_string_literal: true

require 'csv'
require 'digest'
require 'pathname'

module P2m
  # rubocop:disable Metrics/ClassLength
  class OmsUploadLedger
    MARKER_PATTERN = /\AMail\.dat_(\d{8,9})\.zip\z/i
    COMPANION_PATTERN = /\A(\d{8,9})-.+\.csv\z/i
    PRODUCTION_PATTERN = /\A(\d{8,9})-.+\.pdf\z/i
    PREFIX_REPORT_PATTERN = /\A(\d{8,9})_.+\.pdf\z/i
    SUFFIX_REPORT_PATTERN = /\A.+_(\d{8,9})\.pdf\z/i
    REPORT_PATTERN = /\.pdf\z/i
    PRESORT_PATTERN = /\APresort Fields Export_(\d{8,9})\.txt\z/i
    MOVE_PATTERN = /\AMoveResults_(\d{8,9})\.txt\z/i
    OMS_FILE_PATTERNS = [MARKER_PATTERN, COMPANION_PATTERN, PRODUCTION_PATTERN,
                         PREFIX_REPORT_PATTERN, SUFFIX_REPORT_PATTERN, PRESORT_PATTERN,
                         MOVE_PATTERN].freeze
    TSV_OPTIONS = { headers: true, col_sep: "\t", encoding: 'UTF-16LE:UTF-8', liberal_parsing: true }.freeze

    class ImportStarted < StandardError; end
    class ChangedFiles < StandardError; end
    class InvalidDataset < StandardError; end

    PROCESSED_PATH = Pathname.new('/mnt/o/Outputs/DataRunner/02_Processed')

    def initialize(staging_path: OmsStaging::DESTINATION, processed_path: PROCESSED_PATH)
      @staging_path = Pathname.new(staging_path)
      @processed_path = Pathname.new(processed_path)
    end

    def ensure_stageable!(oms_number:)
      archive = processed_path.join(oms_number.to_s)
      raise ChangedFiles, "OMS #{oms_number} is already archived in 02_Processed" if archive.directory?

      imported = OmsUpload.where(oms_number: oms_number).where.not(import_status: 'not_started').exists?
      raise ChangedFiles, "OMS #{oms_number} has already begun import" if imported
    end

    def validate!(oms_number:)
      analysis = analyze(staged_paths(oms_number))
      return analysis if analysis.fetch(:valid)

      messages = analysis.fetch(:findings).filter_map do |finding|
        finding.fetch(:message) if finding.fetch(:severity) == 'error' && finding.fetch(:status) == 'failed'
      end
      raise InvalidDataset, "OMS #{oms_number} cannot be staged: #{messages.join(' ')}"
    end

    def reconcile_imported!(scope: OmsUpload.all)
      scope.where.not(status: %w[removed completed]).find_each.count do |upload|
        imported_at = imported_dataset_at(upload.oms_number)
        next false unless imported_at

        archive = processed_path.join(upload.oms_number)
        attributes = { import_status: 'imported', imported_at: upload.imported_at || imported_at,
                       failure_message: nil }
        if archive.directory?
          attributes.merge!(status: 'completed', archive_status: 'archived',
                            archived_at: upload.archived_at || archive.mtime)
        else
          attributes.merge!(status: 'archiving')
        end
        next false unless attributes.any? { |name, value| upload.public_send(name) != value }

        upload.update!(attributes)
        true
      end
    end

    def staged!(oms_number:, actor:, analysis: nil, checksums: {})
      paths = staged_paths(oms_number)
      marker = marker_for(paths, oms_number)
      analysis ||= analyze(paths)

      OmsUpload.transaction do
        upload = OmsUpload.find_or_initialize_by(oms_number: oms_number, mailer_date: marker.mtime.to_date)
        verify_existing_files!(upload, paths)
        upload.assign_attributes(analysis.fetch(:attributes).merge(staging_attributes(actor, analysis)))
        upload.save!
        replace_files(upload, paths, checksums)
        replace_findings(upload, analysis.fetch(:findings))
        upload
      end
    end

    def remove!(oms_number:, actor:, reason: nil)
      upload = upload_for_staged_job(oms_number)
      upload.with_lock do
        raise ImportStarted, "OMS #{oms_number} cannot be removed after import begins" unless upload.removable?

        yield
        upload.update!(status: 'removed', removed_at: Time.current, removed_by: actor,
                       removal_reason: reason, last_seen_at: Time.current)
      end
      upload
    end

    private

    attr_reader :processed_path, :staging_path

    def imported_dataset_at(oms_number)
      connection = OmsUpload.connection
      oms = connection.quote(oms_number.to_s)
      tables = %w[companions daily_presorts move_results]
      return unless tables.all? { |table| connection.data_source_exists?(table) }
      return unless tables.all? { |table| imported_table_has_oms?(connection, table, oms) }

      selects = tables.map do |table|
        "SELECT MAX(importdatetime) AS imported_at FROM #{connection.quote_table_name(table)} " \
          "WHERE omsnumber = #{oms}"
      end
      connection.select_value("SELECT MAX(imported_at) FROM (#{selects.join(' UNION ALL ')}) imports") || Time.current
    end

    def imported_table_has_oms?(connection, table, oms)
      sql = "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} WHERE omsnumber = #{oms}"
      connection.select_value(sql).to_i.positive?
    end

    def staged_paths(oms_number)
      paths = staging_path.children.select do |path|
        path.file? && file_oms_number(path) == oms_number.to_s
      end
      raise ArgumentError, "no staged files found for OMS #{oms_number}" if paths.empty?

      paths.sort
    end

    def marker_for(paths, oms_number)
      marker = paths.find do |path|
        match = path.basename.to_s.match(MARKER_PATTERN)
        match && match[1] == oms_number.to_s
      end
      raise ArgumentError, "Mail.dat marker not found for OMS #{oms_number}" unless marker

      marker
    end

    def file_oms_number(path)
      OMS_FILE_PATTERNS.each do |pattern|
        match = path.basename.to_s.match(pattern)
        return match[1] if match
      end
      nil
    end

    def upload_for_staged_job(oms_number)
      marker = marker_for(staged_paths(oms_number), oms_number)
      OmsUpload.find_by!(oms_number: oms_number, mailer_date: marker.mtime.to_date)
    end

    def analyze(paths)
      companions = paths.select { |path| path.basename.to_s.match?(COMPANION_PATTERN) }
      companion_rows = companion_rows(companions)
      presort = paths.find { |path| path.basename.to_s.match?(PRESORT_PATTERN) }
      move = paths.find { |path| path.basename.to_s.match?(MOVE_PATTERN) }
      presort_rows = tsv_rows(presort)
      move_rows = tsv_rows(move)
      mailed = presort_rows.count { |row| row['FLD_PIECE_POSTAGE'].present? }
      counts = [companion_rows.length, presort_rows.length, move_rows.length]
      ids_match = matching_ids?(presort, move, presort_rows, move_rows)
      mail_piece_ids = companion_rows.map { |row| row['AIMS mail piece ID'].to_s.strip }
      budget_ids = companion_rows.map { |row| row['Budget 1 - Job ID'].to_s.strip }
      valid = companions.any? && presort.present? && move.present? && counts.uniq.one? && ids_match &&
              identifiers_valid?(mail_piece_ids, budget_ids)

      attributes = summary_attributes(paths, companions, companion_rows, presort, presort_rows, mailed)
      findings = build_findings(companions, presort, move, counts, ids_match, mail_piece_ids, budget_ids,
                                presort_rows.length - mailed)
      { attributes: attributes, findings: findings, valid: valid }
    end

    def identifiers_valid?(mail_piece_ids, budget_ids)
      populated_mail_piece_ids = mail_piece_ids.reject(&:empty?)
      populated_mail_piece_ids.uniq.length == populated_mail_piece_ids.length && budget_ids.none?(&:empty?)
    end

    def summary_attributes(paths, companions, rows, presort, presort_rows, mailed)
      first = rows.first
      {
        budget_job_id: first&.[]('Budget 1 - Job ID'), aims_job_id: first&.[]('AIMS job ID'),
        document_profile: first&.[]('Document profile names'),
        production_workflow: first&.[]('Production workflow name'),
        companion_file_count: companions.length,
        postal_report_count: paths.count do |path|
          path.basename.to_s.match?(REPORT_PATTERN) && !path.basename.to_s.match?(PRODUCTION_PATTERN)
        end,
        input_record_count: rows.length, mailed_record_count: mailed,
        non_mailed_record_count: presort ? presort_rows.length - mailed : nil
      }
    end

    def companion_rows(paths)
      paths.flat_map { |path| CSV.read(path, headers: true, encoding: 'bom|utf-8').map(&:itself) }
    end

    def tsv_rows(path)
      path ? CSV.read(path, **TSV_OPTIONS) : []
    end

    def matching_ids?(presort, move, presort_rows, move_rows)
      return false unless presort && move

      Array(presort_rows['FLD_RECORD_ID']).sort == Array(move_rows['RECORD_ID']).sort
    end

    def staging_attributes(actor, analysis)
      valid = analysis.fetch(:valid)
      {
        status: valid ? 'ready' : 'needs_attention', validation_status: valid ? 'passed' : 'failed',
        import_status: 'not_started',
        archive_status: 'queued', staged_by: actor, staged_at: Time.current,
        last_seen_at: Time.current, removed_by: nil, removed_at: nil,
        removal_reason: nil, failure_message: nil
      }
    end

    def replace_files(upload, paths, checksums)
      upload.files.delete_all
      paths.each do |path|
        name = path.basename.to_s
        upload.files.create!(
          original_filename: name, category: category(path), byte_size: path.size,
          checksum: checksums.fetch(name) { Digest::SHA256.file(path).hexdigest },
          source_modified_at: path.mtime
        )
      end
    end

    def replace_findings(upload, findings)
      upload.findings.delete_all
      findings.each { |attributes| upload.findings.create!(attributes) }
    end

    def build_findings(companions, presort, move, counts, ids_match, mail_piece_ids, budget_ids, non_mailed)
      populated_mail_piece_ids = mail_piece_ids.reject(&:empty?)
      [
        finding('required_files', companions.any? && presort && move, counts.join('/'), 'all three datasets',
                'Companion, Presort, and MoveResults files are required.'),
        finding('row_counts', counts.uniq.one?, counts.join('/'), 'equal',
                'Companion, Presort, and MoveResults row counts must agree.'),
        finding('record_ids', ids_match, ids_match ? 'matching' : 'different', 'matching',
                'Presort and MoveResults record IDs must agree.'),
        finding('aims_mail_piece_ids_unique',
                populated_mail_piece_ids.uniq.length == populated_mail_piece_ids.length,
                (populated_mail_piece_ids.length - populated_mail_piece_ids.uniq.length).to_s, '0',
                'AIMS mail piece IDs must be unique.'),
        finding('budget_job_ids_present', budget_ids.none?(&:empty?), budget_ids.count(&:empty?).to_s, '0',
                'Budget 1 job IDs cannot be blank.'),
        { rule: 'non_mailed', severity: 'info', status: 'observed', observed_value: non_mailed.to_s,
          message: 'Records without postage are retained; no status is inferred.' }
      ]
    end

    def finding(rule, passed, observed, expected, message)
      { rule: rule, severity: 'error', status: passed ? 'passed' : 'failed',
        observed_value: observed, expected_value: expected, message: message }
    end

    def verify_existing_files!(upload, paths)
      return unless upload.persisted? && upload.files.exists?

      existing = upload.files.to_h { |file| [file.original_filename, file.checksum] }
      observed = paths.to_h { |path| [path.basename.to_s, Digest::SHA256.file(path).hexdigest] }
      return if existing == observed

      raise ChangedFiles, "staged files differ from the recorded OMS #{upload.oms_number} dataset"
    end

    def category(path)
      name = path.basename.to_s
      return 'mail_dat' if name.match?(MARKER_PATTERN)
      return 'companion_data' if name.match?(COMPANION_PATTERN)
      return 'production_output' if name.match?(PRODUCTION_PATTERN)
      return 'postal_data' if name.end_with?('.txt')
      return 'postal_report' if name.match?(REPORT_PATTERN)

      'other'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
