# frozen_string_literal: true

module DataRunner
  module IdentityHelpers
    module_function

    def from_metadata(row)
      seed = Integer(row.fetch('seed_value').to_s, 10)
      increment = Integer(row.fetch('increment_value').to_s, 10)
      raise ArgumentError, 'identity metadata has a zero increment' if increment.zero?

      "IDENTITY(#{seed},#{increment})"
    rescue ArgumentError, KeyError => e
      raise ArgumentError, "Invalid identity metadata for #{row['name']}: #{e.message}"
    end

    # Older schema dumps converted unreadable sql_variant metadata to zero.
    # Keep the configured seed, but make those existing DSLs executable.
    def normalize(clause)
      clause.to_s.gsub(/\bIDENTITY\s*\(\s*([+-]?\d+)\s*,\s*[+-]?0+\s*\)/i) do
        "IDENTITY(#{Regexp.last_match(1)},1)"
      end
    end
  end
end
