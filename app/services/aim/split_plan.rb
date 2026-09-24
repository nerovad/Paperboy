# frozen_string_literal: true

module Aim
  # A person's answer to "which pages are which invoice?" for a batch the AI
  # thought held several. Plan step 5.7c.
  #
  # Each row is an invoice: a vendor, an invoice number, and its pages written
  # the way people write them -- "1-3, 5". A row with no pages is a row the
  # person removed. The plan is only accepted when it makes sense as a whole:
  #
  # * every page is a page of this PDF, and belongs to exactly one invoice --
  #   a page left out would be lost, a page used twice would be paid twice;
  # * there are at least two invoices, because one is not a split: the page
  #   offers "Process as one invoice" for that.
  #
  # When the PDF's page count cannot be read, the range checks that need it are
  # skipped rather than guessed; the splitter ignores pages that do not exist.
  class SplitPlan
    Row = Struct.new(:vendor_name, :invoice_number, :pages_text, keyword_init: true)

    PAGE_SPEC = /\A\s*\d+\s*(-\s*\d+\s*)?\z/

    attr_reader :rows, :errors, :page_count

    # The rows a manifest proposes, for the page to show.
    def self.rows_from_manifest(manifest)
      Array(manifest.to_h['invoices']).map do |invoice|
        Row.new(vendor_name: invoice['vendor_name'], invoice_number: invoice['invoice_number'],
                pages_text: page_text(pages_from(invoice['pages'])))
      end
    end

    # "1-3, 5" from [1, 2, 3, 5].
    def self.page_text(pages)
      runs = pages.sort.uniq.slice_when { |a, b| b != a + 1 }
      runs.map { |run| run.size > 1 ? "#{run.first}-#{run.last}" : run.first.to_s }.join(', ')
    end

    # The splitter accepts numbers and "a-b" strings, so a manifest may hold
    # either.
    def self.pages_from(value)
      Array(value).flat_map do |part|
        next [part] if part.is_a?(Integer)

        parse_pages(part.to_s) || []
      end
    end

    # [1, 2, 3, 5] from "1-3, 5", or nil when it is not page numbers.
    def self.parse_pages(text)
      parts = text.to_s.split(',').map(&:strip).compact_blank
      return nil if parts.empty? || parts.any? { |part| !part.match?(PAGE_SPEC) }

      parts.flat_map do |part|
        first, last = part.split('-').map { |number| Integer(number.strip, 10) }
        return nil if last && last < first

        last ? (first..last).to_a : [first]
      end
    end

    def initialize(rows, page_count:)
      @rows = Array(rows).map { |row| row.is_a?(Row) ? row : Row.new(**row.to_h.symbolize_keys.slice(*Row.members)) }
      @page_count = page_count
      @errors = []
    end

    def valid?
      @errors = []
      @invoices = kept_rows.each_with_index.map { |row, index| invoice_for(row, index + 1) }
      check_pages_are_assigned_once
      @errors << 'A split needs at least two invoices. If this is one invoice, use Process as One Invoice.' if @invoices.size < 2
      @errors.empty?
    end

    # The manifest the splitter reads, keeping whatever else it already held --
    # the BU, submitter and owner the AI worker wrote. A blank vendor or
    # invoice number is left out rather than written as null: the splitter
    # names a piece part_N only when the key is absent, and a null crashes it.
    def manifest(base = {})
      valid? unless @invoices
      base.to_h.merge('invoices' => @invoices.map { |invoice| invoice.except(:number).compact.transform_keys(&:to_s) })
    end

    private

    def kept_rows
      @rows.reject { |row| row.pages_text.to_s.strip.empty? }
    end

    def invoice_for(row, number)
      pages = self.class.parse_pages(row.pages_text)
      if pages.nil?
        @errors << "Invoice #{number}: \"#{row.pages_text}\" is not a list of pages. Write them like 1-3, 5."
        pages = []
      end
      out_of_range = page_count ? pages.grep_v(1..page_count) : []
      @errors << "Invoice #{number}: #{pages_phrase(out_of_range)} not in this #{page_count}-page PDF." if out_of_range.any?

      { number: number, vendor_name: row.vendor_name.to_s.strip.presence,
        invoice_number: row.invoice_number.to_s.strip.presence, pages: pages.uniq.sort }
    end

    def check_pages_are_assigned_once
      owners = Hash.new { |hash, page| hash[page] = [] }
      @invoices.each { |invoice| invoice[:pages].each { |page| owners[page] << invoice[:number] } }

      owners.select { |_, numbers| numbers.size > 1 }.sort.each do |page, numbers|
        @errors << "Page #{page} is in invoices #{numbers.to_sentence}. A page belongs to one invoice."
      end
      return unless page_count

      missing = (1..page_count).to_a - owners.keys
      @errors << "#{pages_phrase(missing).upcase_first} not in any invoice." if missing.any?
    end

    # "page 3 is" or "pages 6-7 are".
    def pages_phrase(pages)
      pages.one? ? "page #{pages.first} is" : "pages #{self.class.page_text(pages)} are"
    end
  end
end
