# frozen_string_literal: true

require 'pathname'

module Paperboy
  module SearchCancellation
    DIRECTORY = Pathname.new(ENV.fetch('PAPERBOY_SEARCH_CANCEL_DIR', '/tmp/paperboy-search-cancellations'))
    TOKEN_PATTERN = /\A[a-zA-Z0-9-]+\z/

    class Cancelled < StandardError; end

    module_function

    def cancel!(token)
      path_for(token).tap do |path|
        DIRECTORY.mkpath
        path.write('cancelled')
      end
    end

    def cancelled?(token)
      !token.to_s.empty? && path_for(token).file?
    end

    def cleanup!(token)
      return if token.to_s.empty?

      path = path_for(token)
      path.delete if path.file?
    end

    def path_for(token)
      value = token.to_s
      raise ArgumentError, 'invalid search cancellation token' unless value.match?(TOKEN_PATTERN)

      DIRECTORY.join(value)
    end
  end
end
