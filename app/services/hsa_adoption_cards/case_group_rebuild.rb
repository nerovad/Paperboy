# frozen_string_literal: true

module HsaAdoptionCards
  # dbo.HSA_Adopt_usp_RebuildCaseGroups: re-derives the normalised card
  # table and then relinks every card into its case, from scratch. Run after
  # each batch of newly keyed cards. Returns the group counts by status.
  #
  # The one parameter is the ambiguity margin: when the two best candidates
  # for a card score within this many points of each other, the case is
  # marked REVIEW rather than linked automatically.
  #
  # The procedure has no @AppUser parameter and writes nothing to the search
  # log, so the caller is responsible for recording who ran it.
  class CaseGroupRebuild
    PROCEDURE = 'dbo.HSA_Adopt_usp_RebuildCaseGroups'
    MAPPING = { 'ambiguityMargin' => '@AmbiguityMargin' }.freeze

    DEFAULT_MARGIN = 5
    MARGIN_RANGE = (0..100)

    Result = Data.define(:margin, :counts, :total)

    def self.call(margin: nil)
      new.call(margin: margin)
    end

    def call(margin: nil)
      margin = coerce_margin(margin)
      rows = Procedure.new(PROCEDURE, MAPPING).call({ 'ambiguityMargin' => margin })
      counts = rows.to_h { |row| [row['Status'].to_s, row['Groups'].to_i] }
      Result.new(margin: margin, counts: counts, total: counts.values.sum)
    end

    private

    def coerce_margin(value)
      return DEFAULT_MARGIN if value.to_s.strip.empty?

      margin = Integer(value.to_s.strip, exception: false)
      raise Error, "The ambiguity margin must be a whole number from #{MARGIN_RANGE.min} to #{MARGIN_RANGE.max}." unless margin && MARGIN_RANGE.cover?(margin)

      margin
    end
  end
end
