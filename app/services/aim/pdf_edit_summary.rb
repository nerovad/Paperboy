# frozen_string_literal: true

module Aim
  # The history line for a PDF edit (#181, #182), in words, for what changed
  # since the version before: "rotated page 2; removed page 4; added 2 pages
  # from vendor.pdf; text changed on page 1". Pages of the base PDF go by
  # their own numbers; pages of an added PDF by that file.
  class PdfEditSummary
    # +before+ and +after+ are plans (lists of page hashes); +names+ the
    # added PDFs' names, in source order (source 1 first).
    def initialize(before, after, names)
      @before = normalize(before)
      @after = normalize(after)
      @names = names
    end

    def to_s = parts.presence&.join('; ') || 'no change'

    private

    def normalize(pages) = pages.map { |entry| entry.to_h.deep_symbolize_keys.merge(key: [entry.to_h.symbolize_keys[:source].to_i, entry.to_h.symbolize_keys[:page].to_i]) }

    def parts
      before = @before.index_by { |entry| entry[:key] }
      after = @after.index_by { |entry| entry[:key] }
      kept = @after.select { |entry| before.key?(entry[:key]) }
      [named('removed', @before.reject { |entry| after.key?(entry[:key]) }),
       added(@after.reject { |entry| before.key?(entry[:key]) }),
       ('reordered pages' if kept.map { |entry| entry[:key] } != @before.select { |entry| after.key?(entry[:key]) }.map { |entry| entry[:key] }),
       named('rotated', kept.reject { |entry| turn(entry) == turn(before[entry[:key]]) }),
       named('cropped', kept.reject { |entry| entry[:crop] == before[entry[:key]][:crop] }),
       named('text changed on', kept.reject { |entry| texts(entry) == texts(before[entry[:key]]) }),
       named('text added to', @after.reject { |entry| before.key?(entry[:key]) || texts(entry).empty? })].compact
    end

    def turn(entry) = entry[:rotate].to_i % 360

    def texts(entry) = Array(entry[:texts]).select { |text| text[:text].to_s.strip.present? }

    def added(entries)
      return if entries.empty?

      phrases = entries.group_by { |entry| entry[:key].first }.map do |source, list|
        from = source.zero? ? 'this PDF' : (@names[source - 1] || 'another PDF')
        "#{list.size} #{'page'.pluralize(list.size)} from #{from}"
      end
      "added #{phrases.to_sentence}"
    end

    def named(verb, entries)
      return if entries.empty?

      own = entries.select { |entry| entry[:key].first.zero? }.map { |entry| entry[:key].last }
      others = entries.size - own.size
      list = [("#{'page'.pluralize(own.size)} #{own.to_sentence}" if own.any?), ("#{others} added #{'page'.pluralize(others)}" if others.positive?)]
      "#{verb} #{list.compact.to_sentence}"
    end
  end
end
