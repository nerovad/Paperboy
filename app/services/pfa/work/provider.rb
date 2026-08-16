# frozen_string_literal: true

module Pfa
  module Work
    # Contract implemented by applications that publish work into PFA.
    class Provider
      def inbox_items(viewer:, filters: {})
        raise NotImplementedError
      end

      def records(viewer:, filters: {})
        raise NotImplementedError
      end

      def status_options(viewer:)
        records(viewer: viewer).filter_map(&:status).uniq.sort
      end
    end
  end
end
