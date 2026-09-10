# frozen_string_literal: true

module Aim
  # Raised when an AIM environment variable a caller needs is not set.
  #
  # AIM never guesses a path. A wrong guess puts invoices in a folder nobody
  # is watching, so a missing variable has to be loud. This is raised at the
  # point of use and never during boot -- an AIM misconfiguration must not
  # take down Billing, Forms or Print 2 Mail along with it.
  class MissingConfiguration < StandardError
    def self.for(variable, subject)
      new("#{subject} is not configured. Set #{variable}.")
    end
  end
end
