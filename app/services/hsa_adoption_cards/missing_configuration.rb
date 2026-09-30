# frozen_string_literal: true

module HsaAdoptionCards
  # An HSA_ADOPT_* environment variable a caller needs is not set. Raised at
  # the point of use, never at boot, so a misconfiguration here cannot take
  # any other app down with it.
  class MissingConfiguration < Error
    extend Paperboy::MissingConfiguration
  end
end
