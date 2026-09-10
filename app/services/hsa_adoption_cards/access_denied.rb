# frozen_string_literal: true

module HsaAdoptionCards
  # The SQL side refused the call: the connecting account is not in the
  # HSA_Adopt_Searchers role, or cannot open GSA_Scan at all.
  class AccessDenied < Error; end
end
