# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Aim
  # Cuts a batch into the invoices an approved split names, in Rails (#192;
  # it was the worker's splitting.py): each invoice's pages of the current
  # PDF -- <batch id>.pdf, so edits made before the split carry through --
  # written to <batch id>_SPLIT_<n>, a row inserted for each as +received+
  # with the +extract+ command, for the AI to read, and the batch ended as
  # +split+, its history naming them.
  #
  # All or nothing: the pieces are written first, and the rows and the
  # batch's move are one transaction, so a failure leaves the batch waiting to
  # be split and no piece behind. Run again on a split batch, it is refused
  # (split is an end state).
  class BatchSplit
    class Failed < StandardError; end

    # What a piece keeps of the batch it came from.
    KEPT = %w[budget_unit submitter assigned_to assigned_employee_id assignment_source source_filename source_path].freeze

    def initialize(invoice, plan)
      @invoice = invoice
      @plan = plan
    end

    # The children, in order. Raises Failed, or IllegalTransition when the
    # batch is not waiting to be split.
    def run!(actor:)
      raise Aim::Invoice::IllegalTransition, "#{@invoice.batch_id} is not waiting to be split." unless @invoice.can_move_to?('split')

      pieces = @plan.manifest(@invoice.manifest_data)['invoices']
      written = write_pieces(pieces)
      Aim::Invoice.transaction do
        children = pieces.each_with_index.map { |piece, index| insert_child(piece, index + 1, written[index], actor) }
        @invoice.transition_to!('split', actor: actor, command: nil, lease_owner: nil, lease_until: nil,
                                         note: "split into #{children.size}: #{children.map(&:batch_id).join(', ')}")
        children
      end
    rescue StandardError
      written&.each { |path| FileUtils.rm_rf(File.dirname(path)) }
      raise
    end

    private

    def child_id(number) = "#{@invoice.batch_id}_SPLIT_#{number}"

    def write_pieces(pieces)
      source = @invoice.pdf_path
      raise Failed, 'the PDF is not in the store' unless File.file?(source)

      editor = Aim::PdfEdit.new(source)
      written = []
      pieces.each_with_index do |piece, index|
        path = File.join(Aim::InvoiceDirectoryService.instance.store_dir, child_id(index + 1), "#{child_id(index + 1)}.pdf")
        # Only folders made here are ever removed again.
        raise Failed, "#{File.basename(File.dirname(path))} is already in the store" if Dir.exist?(File.dirname(path))

        FileUtils.mkdir_p(File.dirname(path))
        written << path
        editor.write(path, piece['pages'].map { |page| { 'source' => 0, 'page' => page } })
      end
      written
    rescue Aim::PdfEdit::Unreadable => e
      FileUtils.rm_rf(written.map { |path| File.dirname(path) }) if written
      raise Failed, "the PDF could not be cut (#{e.message.truncate(80)})"
    end

    def insert_child(piece, number, path, actor)
      Aim::Invoice.create!(
        **@invoice.attributes.slice(*KEPT).symbolize_keys,
        batch_id: child_id(number), state: 'received', command: 'extract', actor: actor, parent_id: @invoice.id,
        split_check: false, page_count: piece['pages'].size, content_hash: Digest::SHA256.file(path).hexdigest,
        extracted_vendor_name: piece['vendor_name'], invoice_number: piece['invoice_number']
      )
    end
  end
end
