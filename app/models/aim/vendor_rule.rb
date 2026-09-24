# frozen_string_literal: true

module Aim
  # Plain-English hints the vision prompt is given for one vendor: where the
  # invoice number sits, which total to take. One row per official vendor
  # name, the rules one per line.
  class VendorRule < Record
    validates :vendor_name, :rules, presence: true
    validates :vendor_name, uniqueness: { case_sensitive: false }

    before_validation { self.vendor_name = vendor_name.to_s.squish }
    before_validation { self.rules = rules.to_s.strip }

    scope :by_name, -> { order(Arel.sql('LOWER(vendor_name)')) }

    def self.for_vendor(vendor_name)
      where('LOWER(vendor_name) = ?', vendor_name.to_s.squish.downcase).first
    end

    def rule_lines = rules.to_s.lines.map(&:strip).compact_blank
  end
end
