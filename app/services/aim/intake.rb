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
    ID_HASH_ALPHABET = ('A'..'Z').to_a + ('0'..'9').to_a
    # Windows will not take these in a file name, and the batch id names a folder.
    UNSAFE_IN_NAME = %r{[<>:"/\\|?*\x00-\x1F]}

    Result = Struct.new(:invoice, :pdf_path, keyword_init: true)

    def initialize(directory_service: Aim::InvoiceDirectoryService.instance)
      @directory_service = directory_service
    end

    # +io+ is anything that responds to #read (an uploaded file). The
    # submitter is the person who brought it; the owner is whose queue it goes
    # to, nil for the BU's shared queue.
    def store(io, original_filename:, budget_unit:, submitter:, owner:, actor:, source: 'upload', source_path: nil)
      batch_id = mint_batch_id(budget_unit, original_filename)
      folder = File.join(@directory_service.store_dir, batch_id)
      pdf_path = File.join(folder, "#{batch_id}.pdf")

      FileUtils.mkdir_p(folder)
      bytes = io.read
      File.binwrite(pdf_path, bytes)

      invoice = Aim::Invoice.create!(
        batch_id: batch_id, state: 'received', command: 'extract', actor: actor,
        budget_unit: budget_unit, submitter: submitter,
        assigned_to: owner.presence, assignment_source: (source if owner.present?),
        source_filename: original_filename.to_s.first(260), source_path: source_path&.first(1000),
        content_hash: Digest::SHA256.hexdigest(bytes), page_count: page_count(bytes)
      )
      Result.new(invoice: invoice, pdf_path: pdf_path)
    rescue StandardError
      FileUtils.rm_rf(folder) if folder && Dir.exist?(folder) && Aim::Invoice.where(batch_id: batch_id).none?
      raise
    end

    # v1's format, kept: {BU}.{YYYYMMDD_HHMMSS}.{name}-[HASH].
    def mint_batch_id(budget_unit, original_filename)
      name = File.basename(original_filename.to_s, '.*').gsub(UNSAFE_IN_NAME, '').squish.first(80).presence || 'scan'
      stamp = Time.zone.now.strftime('%Y%m%d_%H%M%S')
      code = Array.new(4) { ID_HASH_ALPHABET[SecureRandom.random_number(ID_HASH_ALPHABET.size)] }.join
      "#{budget_unit}.#{stamp}.#{name}-[#{code}]"
    end

    private

    def page_count(bytes)
      require 'pdf-reader'
      PDF::Reader.new(StringIO.new(bytes)).page_count
    rescue StandardError
      nil
    end
  end
end
