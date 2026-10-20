# frozen_string_literal: true

require 'pdf-reader'

module Aim
  # An invoice's PDF as versions (#182, replacing #181's file copies): each
  # swap, edit and restore is an Aim::PdfVersion -- a base PDF and any
  # inserted PDFs kept in the invoice's store folder, plus the editor's plan
  # for them. <batch id>.pdf is always the current version rendered, so the
  # viewer, the AI, the export and the approval stamp read it as before, and
  # the editor reopens the plan, its text boxes still editable, until Fiscal
  # archives the invoice. Nothing is ever deleted: a restore is a new version.
  #
  # The render is written beside <batch id>.pdf and renamed into place, so
  # nobody is served half a file; a version that cannot be rendered is not
  # saved, and the PDF stays as it was.
  module PdfVersions
    # Where a person may change the PDF: while it is worked, and with Fiscal
    # until Fiscal archives it -- not while the AI or the export has it, nor
    # once rejected, deleted, split or purged.
    EDITABLE_STATES = %w[needs_review needs_split ready_for_approval failed approved exported].freeze
    MAX_BYTES = 50.megabytes
    LEGACY = /\.v(\d+)\.pdf\z/ # #181's kept copies

    class Refused < StandardError; end

    module_function

    def editable?(invoice)
      return false unless EDITABLE_STATES.include?(invoice.state) && invoice.pdf_purged_at.nil?

      !Aim::FiscalRecord.exists?(invoice_id: invoice.id, status: 'archived')
    end

    def all(invoice) = Aim::PdfVersion.where(invoice_id: invoice.id).order(:number)

    def current(invoice) = all(invoice).last

    # Checks +path+ is a PDF AIM can read and edit; returns its page count or
    # raises Refused.
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

    # A new base PDF, as it is.
    def swap!(invoice, upload, name:, actor:)
      refuse_unless_editable(invoice)
      check!(upload, name: name)
      start!(invoice)
      number = next_number(invoice)
      base = keep_file(invoice, upload, "base-#{number}")
      commit!(invoice, number: number, kind: 'swap', base_file: base, actor: actor, note: "PDF swapped for #{name}")
    end

    # The editor's +pages+ over the current base and inserts, with +uploads+
    # ([[path, name], ...]) added as further inserts.
    def edit!(invoice, pages, uploads, actor:)
      refuse_unless_editable(invoice)
      uploads.each { |path, name| check!(path, name: name) }
      from = start!(invoice)
      number = next_number(invoice)
      inserts = from.insert_files + uploads.each_with_index.map { |(path, _), index| keep_file(invoice, path, "insert-#{number}-#{index + 1}") }
      before = from.plan_pages || (1..page_count(from.base_path)).map { |page| { source: 0, page: page } }
      summary = Aim::PdfEditSummary.new(before, pages, from.insert_files.map { 'an added PDF' } + uploads.map(&:last)).to_s
      commit!(invoice, number: number, kind: 'edit', base_file: from.base_file, inserts: inserts, plan: pages,
                       actor: actor, note: "PDF edited: #{summary}")
    end

    # Version +number+ made current again, as a new version.
    def restore!(invoice, number, actor:)
      refuse_unless_editable(invoice)
      start!(invoice)
      old = all(invoice).find_by(number: number) or raise Refused, "There is no version #{number}."
      commit!(invoice, number: next_number(invoice), kind: 'restore', base_file: old.base_file, inserts: old.insert_files,
                       plan: old.plan_pages, actor: actor, note: "PDF restored to version #{number}")
    end

    # Writes +version+ as a PDF at +path+.
    def render_to(version, path)
      return FileUtils.cp(version.base_path, path) if version.plan_pages.nil?

      Aim::PdfEdit.new(version.base_path, inserts: version.insert_paths).write(path, version.plan_pages)
    end

    # The first time an invoice's PDF changes: the PDF as it is now becomes
    # version 1 (#181's kept copies, if any, before it, oldest first).
    # Returns the current version.
    def start!(invoice)
      current(invoice) || Aim::PdfVersion.transaction do
        legacy(invoice).each do |number, path|
          FileUtils.mv(path, File.join(invoice.store_dir, "#{invoice.batch_id}.base-#{number}.pdf"))
          Aim::PdfVersion.create!(invoice: invoice, number: number, kind: number == 1 ? 'received' : 'edit', base_file: "#{invoice.batch_id}.base-#{number}.pdf",
                                  created_by: Aim::Audited::SYSTEM_ACTOR, note: 'kept from before versions were tracked')
        end
        number = next_number(invoice)
        base = keep_file(invoice, invoice.pdf_path, "base-#{number}")
        Aim::PdfVersion.create!(invoice: invoice, number: number, kind: number == 1 ? 'received' : 'edit', base_file: base,
                                created_by: Aim::Audited::SYSTEM_ACTOR, note: number == 1 ? 'as received' : 'as it was before versions were tracked')
      end
    end

    # --- writing -----------------------------------------------------------------

    def commit!(invoice, number:, kind:, base_file:, actor:, note:, inserts: [], plan: nil)
      version = Aim::PdfVersion.new(invoice: invoice, number: number, kind: kind, base_file: base_file, created_by: actor, note: note,
                                    inserts: (inserts.to_json if inserts.any?), plan: plan&.to_json, created_at: Time.current)
      temporary = "#{invoice.pdf_path}.part"
      render_to(version, temporary)
      pages = check!(temporary, name: 'the new PDF')
      Aim::PdfVersion.transaction do
        version.save!
        File.rename(temporary, invoice.pdf_path)
        invoice.update_columns(page_count: pages)
        invoice.events.create!(action: 'pdf_changed', actor: actor, note: [note, "version #{number}", after_approval(invoice)].compact.join('; '))
      end
      restamp(invoice)
      version
    rescue Aim::PdfEdit::Unreadable => e
      raise Refused, e.message
    ensure
      FileUtils.rm_f(temporary) if temporary
    end

    def keep_file(invoice, source, label)
      name = "#{invoice.batch_id}.#{label}.pdf"
      FileUtils.mkdir_p(invoice.store_dir)
      FileUtils.cp(source, File.join(invoice.store_dir, name))
      name
    end

    def next_number(invoice) = (all(invoice).maximum(:number) || 0) + 1

    # #181's <batch id>.v<n>.pdf copies, oldest first. Read from the folder's
    # names, not a glob: batch ids end in "[AB12]", a glob character class.
    def legacy(invoice)
      return [] unless Dir.exist?(invoice.store_dir)

      prefix = "#{invoice.batch_id}.v"
      Dir.children(invoice.store_dir).filter_map do |name|
        number = name.delete_prefix(prefix)[/\A(\d+)\.pdf\z/, 1] if name.start_with?(prefix)
        [number.to_i, File.join(invoice.store_dir, name)] if number
      end.sort
    end

    def page_count(path) = PDF::Reader.new(path).page_count

    def refuse_unless_editable(invoice)
      raise Refused, 'This invoice\'s PDF cannot be changed now.' unless editable?(invoice)
    end

    def after_approval(invoice)
      'changed after approval; saved Fiscal reports keep their copy' if Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state)
    end

    # The approval stamp is redone on the new PDF.
    def restamp(invoice)
      FileUtils.rm_f(Aim::ApprovalStamp.path(invoice))
      record = Aim::FiscalRecord.find_by(invoice_id: invoice.id)
      Aim::ApprovalStamp.stamp!(record) if record
    end
  end
end
