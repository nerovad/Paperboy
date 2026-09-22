# frozen_string_literal: true

module Dam
  module ResourceSpace
    # A folder written by Dam::ResourceSpace::Export, read back on the server
    # that imports it.
    #
    # It arrives by scp from another machine, so it is treated as input: every
    # path inside catalog.json must resolve inside the bundle itself, and one
    # that climbs out — "../../etc/passwd" — is refused rather than read.
    class Bundle
      class Invalid < StandardError; end

      def initialize(root)
        @root = Pathname(root).expand_path
        raise Invalid, "No ResourceSpace export at #{@root} (catalog.json is missing)" unless catalog_file.file?
        raise Invalid, "#{catalog_file} is format #{document['format']}; this import reads #{Export::FORMAT}" unless
          document['format'] == Export::FORMAT
      end

      def fields = document.fetch('fields', [])

      def collections = document.fetch('collections', [])

      def resources = document.fetch('resources', [])

      def exported_at = document['exported_at']

      # A file the bundle carries, or nil when the catalogue names none or the
      # copy never arrived. Raises for a path that would leave the bundle.
      def path(relative)
        return nil if relative.blank?

        candidate = @root.join(relative).expand_path
        raise Invalid, "#{relative} is outside the export" unless candidate.to_s.start_with?("#{@root}/")

        candidate.file? && candidate.size.positive? ? candidate : nil
      end

      private

      def catalog_file = @root.join('catalog.json')

      def document
        @document ||= JSON.parse(catalog_file.read)
      rescue JSON::ParserError => e
        raise Invalid, "catalog.json is not readable JSON: #{e.message}"
      end
    end
  end
end
