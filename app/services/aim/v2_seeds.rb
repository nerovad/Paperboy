# frozen_string_literal: true

module Aim
  # Reads the v1 JSON files into the v2 tables. Used by lib/tasks/aim_v2.rake.
  module V2Seeds
    module_function

    # A bare file name lives in the worker install folder.
    def resolve(configured)
      service = Aim::InvoiceDirectoryService.instance
      translated = service.translate_path(configured.to_s)
      return translated if translated.include?('/')

      File.join(service.program_dir, translated)
    end

    # vendor_aliases.json: {"AS READ": "Official Name", ...}
    def seed_aliases(path)
      data = JSON.parse(File.read(path))
      raise ArgumentError, "#{path} is not an object of extracted => normalized names" unless data.is_a?(Hash)

      added = kept = 0
      data.each do |extracted, normalized|
        next if extracted.to_s.squish.blank? || normalized.to_s.squish.blank?

        if Aim::VendorAlias.where('LOWER(extracted_name) = ?', extracted.to_s.squish.downcase).exists?
          kept += 1
        else
          Aim::VendorAlias.create!(extracted_name: extracted, normalized_name: normalized, learned_by: 'seed',
                                   note: "seeded from #{File.basename(path)}")
          added += 1
        end
      end
      [added, kept]
    end

    # vendor_rules.json: {"Official Name": ["rule", "rule"], ...}
    def seed_rules(path)
      data = JSON.parse(File.read(path))
      raise ArgumentError, "#{path} is not an object of vendor => rules" unless data.is_a?(Hash)

      added = kept = 0
      data.each do |vendor, rules|
        lines = Array(rules).map { |rule| rule.to_s.strip }.compact_blank
        next if vendor.to_s.squish.blank? || lines.empty?

        if Aim::VendorRule.for_vendor(vendor)
          kept += 1
        else
          Aim::VendorRule.create!(vendor_name: vendor, rules: lines.join("\n"), updated_by: 'seed')
          added += 1
        end
      end
      [added, kept]
    end
  end
end
