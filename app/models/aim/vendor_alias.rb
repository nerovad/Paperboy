# frozen_string_literal: true

module Aim
  # One spelling the AI has read for a vendor, and the official name it means.
  # The worker matches extracted names against these at every extraction; a
  # reviewer teaches a new one from the review page or the aliases screen.
  class VendorAlias < Record
    validates :extracted_name, :normalized_name, presence: true
    validates :extracted_name, uniqueness: { case_sensitive: false }

    before_validation { self.extracted_name = extracted_name.to_s.squish }
    before_validation { self.normalized_name = normalized_name.to_s.squish }

    scope :by_name, -> { order(Arel.sql('LOWER(extracted_name)')) }

    # Teach a spelling, or correct one already taught.
    def self.learn!(extracted_name:, normalized_name:, learned_by:, note: nil)
      extracted = extracted_name.to_s.squish
      normalized = normalized_name.to_s.squish
      raise ArgumentError, 'Extracted vendor name is required.' if extracted.blank?
      raise ArgumentError, 'Official vendor name is required.' if normalized.blank?

      row = where('LOWER(extracted_name) = ?', extracted.downcase).first || new(extracted_name: extracted)
      row.update!(normalized_name: normalized, learned_by: learned_by, note: note)
      # The official name maps to itself, so a clean read of it is known too.
      unless extracted.casecmp?(normalized) || where('LOWER(extracted_name) = ?', normalized.downcase).exists?
        create!(extracted_name: normalized, normalized_name: normalized, learned_by: learned_by, note: note)
      end
      row
    end

    def self.official_names
      distinct.pluck(:normalized_name).map(&:squish).compact_blank.uniq.sort_by(&:downcase)
    end
  end
end
