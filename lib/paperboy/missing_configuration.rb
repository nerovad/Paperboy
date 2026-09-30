# frozen_string_literal: true

module Paperboy
  # The shared shape of an app's "an environment variable is not set" error.
  # Extend an exception class with it to get +.for+, which names the thing
  # that is not configured and the variable to set:
  #
  #   class MissingConfiguration < StandardError
  #     extend Paperboy::MissingConfiguration
  #   end
  #
  #   raise MissingConfiguration.for('AIM_STORE_DIR', 'The AIM store folder')
  #   # => "The AIM store folder is not configured. Set AIM_STORE_DIR."
  #
  # Each app keeps its own class (and superclass) so its rescues stay scoped
  # to it. Raise at the point of use, never at boot, so one app's
  # misconfiguration cannot take another down.
  module MissingConfiguration
    def self.message(variable, subject) = "#{subject} is not configured. Set #{variable}."

    def for(variable, subject)
      new(MissingConfiguration.message(variable, subject))
    end
  end
end
