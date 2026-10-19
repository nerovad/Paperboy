# frozen_string_literal: true

module Aim
  # The history line for a PDF edit (#181), in words: "rotated page 2;
  # removed page 4; added 2 pages from vendor.pdf". Pages of the invoice's own
  # PDF go by their old numbers; pages added from another PDF by that file.
  class PdfEditSummary
    def initialize(pages, insert_names, original_count: nil)
      @pages = pages.map { |entry| entry.to_h.symbolize_keys }
      @names = insert_names
      @original_count = original_count
    end

    def to_s = parts.presence&.join('; ') || 'no change'

    private

    def parts
      own = @pages.select { |entry| entry[:source].to_i.zero? }.map { |entry| entry[:page].to_i }
      [removed(own), added, ('reordered pages' if own != own.sort || moved_inserts?),
       touched('rotated', &rotated), touched('cropped') { |entry| entry[:crop].present? },
       touched('text added to') { |entry| Array(entry[:texts]).any? { |text| text.to_h.symbolize_keys[:text].to_s.strip.present? } }].compact
    end

    def rotated = ->(entry) { (entry[:rotate].to_i % 360).nonzero? }

    def removed(own)
      return if @original_count.nil?

      gone = (1..@original_count).to_a - own
      "removed #{pages_named(gone)}" if gone.any?
    end

    def added
      counts = @pages.reject { |entry| entry[:source].to_i.zero? }.group_by { |entry| entry[:source].to_i }
      phrases = counts.map { |source, entries| "#{entries.size} #{'page'.pluralize(entries.size)} from #{@names[source - 1] || 'another PDF'}" }
      "added #{phrases.to_sentence}" if phrases.any?
    end

    # Added pages that do not sit together at the end count as a reorder.
    def moved_inserts?
      sources = @pages.map { |entry| entry[:source].to_i }
      first_added = sources.index(&:positive?)
      first_added && sources[first_added..].any?(&:zero?)
    end

    def touched(verb, &test)
      hits = @pages.select(&test)
      return if hits.empty?

      own = hits.select { |entry| entry[:source].to_i.zero? }.map { |entry| entry[:page].to_i }
      others = hits.size - own.size
      named = [(pages_named(own) if own.any?), ("#{others} added #{'page'.pluralize(others)}" if others.positive?)].compact
      "#{verb} #{named.to_sentence}"
    end

    def pages_named(numbers) = "#{'page'.pluralize(numbers.size)} #{numbers.to_sentence}"
  end
end
