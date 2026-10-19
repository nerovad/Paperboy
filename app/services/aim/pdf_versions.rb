# frozen_string_literal: true

require 'pdf-reader'

module Aim
  # Replacing an invoice's PDF (#181), by a swap or an edit, at once. The
  # file there now is kept beside it as <batch id>.v<n>.pdf before the new one
  # takes its name; the history says who and what. An approved invoice is
  # stamped again on the spot. The invoice keeps its place, owner, AIM # and
  # fields.
  #
  # The new file is written beside the old and renamed into place, so nobody
  # is ever served half a file. A replacement that fails leaves the old PDF
  # where it was.
  module PdfVersions
    # Where a person may change the PDF: while it is worked, and with Fiscal
    # until Fiscal archives it -- not while the AI or the export has it, nor
    # once rejected, deleted, split or purged.
    EDITABLE_STATES = %w[needs_review needs_split ready_for_approval failed approved exported].freeze
    MAX_BYTES = 50.megabytes

    class Refused < StandardError; end

    module_function

    def editable?(invoice)
      return false unless EDITABLE_STATES.include?(invoice.state) && invoice.pdf_purged_at.nil?

      !Aim::FiscalRecord.exists?(invoice_id: invoice.id, status: 'archived')
    end

    # The versions kept so far, oldest first: [[n, path], ...].
    # Read from the folder's names, not a glob: batch ids end in "[AB12]",
    # which a glob takes for a character class.
    def kept(invoice)
      return [] unless Dir.exist?(invoice.store_dir)

      prefix = "#{invoice.batch_id}.v"
      Dir.children(invoice.store_dir).filter_map do |name|
        number = name.delete_prefix(prefix)[/\A(\d+)\.pdf\z/, 1] if name.start_with?(prefix)
        [number.to_i, File.join(invoice.store_dir, name)] if number
      end.sort
    end

    # Checks +path+ is a PDF AIM can read and edit; raises Refused if not.
    def check!(path, name: File.basename(path))
      raise Refused, "#{name} is larger than #{MAX_BYTES / 1.megabyte} MB" if File.size(path) > MAX_BYTES
      raise Refused, "#{name} is not a PDF" unless File.binread(path, 5) == '%PDF-'

      reader = PDF::Reader.new(path)
      raise Refused, "#{name} is password-protected" if reader.objects.encrypted?
      raise Refused, "#{name} has no pages" if reader.page_count.zero?

      reader.page_count
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise Refused, "#{name} could not be read (#{e.message.truncate(80)})"
    end

    # Puts the PDF at +new_path+ in the invoice's place; returns the version
    # number the old file was kept as (nil when there was none).
    def replace!(invoice, new_path, actor:, note:, name: nil)
      raise Refused, 'This invoice\'s PDF cannot be changed now.' unless editable?(invoice)

      pages = check!(new_path, name: name || File.basename(new_path))
      FileUtils.mkdir_p(invoice.store_dir)
      version = keep_current(invoice)
      temporary = "#{invoice.pdf_path}.part"
      FileUtils.cp(new_path, temporary)
      File.rename(temporary, invoice.pdf_path)
      invoice.update_columns(page_count: pages)
      invoice.events.create!(action: 'pdf_changed', actor: actor,
                             note: [note, ("previous PDF kept as version #{version}" if version), after_approval(invoice)].compact.join('; '))
      restamp(invoice)
      version
    ensure
      FileUtils.rm_f(temporary) if temporary
    end

    def keep_current(invoice)
      return unless File.file?(invoice.pdf_path)

      version = (kept(invoice).last&.first || 0) + 1
      FileUtils.cp(invoice.pdf_path, File.join(invoice.store_dir, "#{invoice.batch_id}.v#{version}.pdf"))
      version
    end

    def after_approval(invoice)
      'changed after approval; saved Fiscal reports keep their copy' if Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state)
    end

    # The approval stamp is redone on the new PDF; until it is, the review and
    # Fiscal pages show the new PDF as it is.
    def restamp(invoice)
      FileUtils.rm_f(Aim::ApprovalStamp.path(invoice))
      record = Aim::FiscalRecord.find_by(invoice_id: invoice.id)
      Aim::ApprovalStamp.stamp!(record) if record
    end
  end
end
