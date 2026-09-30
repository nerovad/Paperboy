# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'securerandom'

module Aim
  # Takes a PDF in and makes it an invoice: the file goes to the store under a
  # freshly minted batch id, and one row is inserted as +received+ with the
  # +extract+ command. This is exactly what the worker's intake does for a
  # file dropped on the share; the Upload page does it from Paperboy.
  class Intake
    # How a batch id is made is written once, in a file the v2 worker ships
    # with and reads too: a file dropped on the share and a file uploaded here
    # get their ids -- and store folders -- the same way.
    # test/python/aim_v2/batch_id_cases.json holds the cases both sides check.
    BATCH_ID_SPEC_FILE = Rails.root.join('script/python/aim/v2/batch_id_spec.json')
    BATCH_ID_SPEC = JSON.parse(BATCH_ID_SPEC_FILE.read).freeze
    ID_HASH_ALPHABET = BATCH_ID_SPEC.dig('code', 'alphabet').chars.freeze
    # Windows will not take these in a file name, and the batch id names a folder.
    UNSAFE_IN_NAME = Regexp.new(BATCH_ID_SPEC.dig('name', 'unsafe_pattern'))
    ID_TIME_ZONE = ActiveSupport::TimeZone[BATCH_ID_SPEC.dig('stamp', 'time_zone')] ||
                   raise(ArgumentError, "#{BATCH_ID_SPEC_FILE}: unknown time zone")

    Result = Struct.new(:invoice, :pdf_path, keyword_init: true)

    def initialize(directory_service: Aim::InvoiceDirectoryService.instance)
      @directory_service = directory_service
    end

    # +io+ is anything that responds to #read (an uploaded file). The
    # submitter is the person who brought it; the owner is whose queue it goes
    # to, nil for the BU's shared queue: a name, or { name:, employee_id: }.
    def store(io, original_filename:, budget_unit:, submitter:, owner:, actor:, source: 'upload', source_path: nil)
      owner_employee_id = owner.is_a?(Hash) ? owner[:employee_id] : nil
      owner = owner[:name] if owner.is_a?(Hash)
      batch_id = mint_batch_id(budget_unit, original_filename)
      folder = File.join(@directory_service.store_dir, batch_id)
      pdf_path = File.join(folder, "#{batch_id}.pdf")

      FileUtils.mkdir_p(folder)
      bytes = io.read
      File.binwrite(pdf_path, bytes)

      invoice = Aim::Invoice.create!(
        batch_id: batch_id, state: 'received', command: 'extract', actor: actor,
        budget_unit: budget_unit, submitter: submitter,
        assigned_to: owner.presence, assigned_employee_id: owner_employee_id,
        assignment_source: (source if owner.present? || owner_employee_id),
        source_filename: original_filename.to_s.first(260), source_path: source_path&.first(1000),
        content_hash: Digest::SHA256.hexdigest(bytes), page_count: page_count(bytes)
      )
      Result.new(invoice: invoice, pdf_path: pdf_path)
    rescue StandardError
      FileUtils.rm_rf(folder) if folder && Dir.exist?(folder) && Aim::Invoice.where(batch_id: batch_id).none?
      raise
    end

    # {BU}.{YYYYMMDD_HHMMSS}.{name}-[HASH], by the shared spec.
    def mint_batch_id(budget_unit, original_filename, now: Time.current, code: nil)
      parts = { 'budget_unit' => budget_unit, 'stamp' => now.in_time_zone(ID_TIME_ZONE).strftime(BATCH_ID_SPEC.dig('stamp', 'format')),
                'name' => self.class.batch_name(original_filename), 'code' => code || random_code }
      BATCH_ID_SPEC['format'].gsub(/\{(\w+)\}/) { parts.fetch(Regexp.last_match(1)).to_s }
    end

    # The name part: the file's stem, safe for a Windows folder name.
    def self.batch_name(original_filename)
      rules = BATCH_ID_SPEC['name']
      File.basename(original_filename.to_s, '.*').gsub(UNSAFE_IN_NAME, '').squish
          .first(rules['max_length']).presence || rules['fallback']
    end

    private

    def random_code
      Array.new(BATCH_ID_SPEC.dig('code', 'length')) { ID_HASH_ALPHABET[SecureRandom.random_number(ID_HASH_ALPHABET.size)] }.join
    end

    def page_count(bytes)
      require 'pdf-reader'
      PDF::Reader.new(StringIO.new(bytes)).page_count
    rescue StandardError
      nil
    end
  end
end
