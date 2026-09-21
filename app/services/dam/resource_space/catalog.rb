# frozen_string_literal: true

module Dam
  module ResourceSpace
    # What ResourceSpace knows about its resources, which is everything the
    # filestore does not say.
    #
    # Its metadata lives in nodes rather than columns: every value is a row in
    # `node` against a field in `resource_type_field`, joined to a resource
    # through `resource_node`. So a title is a lookup, not a column, and the
    # `resource.title` column is empty for nearly everything.
    class Catalog
      # ResourceSpace's archive states. 0 is live; anything else is somewhere
      # in a review or deletion workflow and has no business in the library.
      ACTIVE = 0

      # The fields worth carrying over, by their ResourceSpace name, mapped to
      # the key a Dam::MetadataField uses. Title is handled on its own because
      # it becomes the asset's title rather than a metadata row.
      TITLE_FIELD = 'title'
      FIELDS = {
        'keywords' => 'keywords', 'subject' => 'subject', 'event' => 'event',
        'caption' => 'caption', 'credit' => 'credit', 'notes' => 'notes',
        'country' => 'country', 'person' => 'person', 'date' => 'captured_on',
        'originalfilename' => 'original_filename'
      }.freeze

      # What those keys look like on the DAM side. Advanced Search builds its
      # custom-criteria picker from these rows, so an import into a library
      # that has never heard of "credit" has to add the field before the value
      # has anywhere to go — Dam::MetadataAssignment drops values for fields
      # nobody configured, which is right for a form and wrong for an import.
      DAM_FIELDS = [
        { key: 'keywords', label: 'Keywords', field_type: 'text' },
        { key: 'subject', label: 'Subject', field_type: 'text' },
        { key: 'event', label: 'Event', field_type: 'text' },
        { key: 'caption', label: 'Caption', field_type: 'text' },
        { key: 'credit', label: 'Credit', field_type: 'text' },
        { key: 'notes', label: 'Notes', field_type: 'text' },
        { key: 'country', label: 'Country', field_type: 'text' },
        { key: 'person', label: 'Named person(s)', field_type: 'text' },
        { key: 'captured_on', label: 'Captured on', field_type: 'date' },
        { key: 'original_filename', label: 'Original filename', field_type: 'text' }
      ].freeze

      def initialize(client = Client.new)
        @client = client
      end

      def active_count
        @client.query("SELECT COUNT(*) AS n FROM resource WHERE archive = #{ACTIVE}").first['n'].to_i
      end

      # Resources in ref order, a page at a time, so an import of 14,000 does
      # not hold them all in memory and can be resumed where it stopped.
      def resources(after_ref: 0, limit: 500)
        @client.query(<<~SQL, after_ref, limit)
          SELECT ref, title, resource_type, file_extension, file_size, file_path,
                 creation_date, created_by, has_image
          FROM resource
          WHERE archive = #{ACTIVE} AND ref > %s
          ORDER BY ref
          LIMIT %s
        SQL
      end

      # { resource_ref => { field_key => "value, value" } } for the fields in
      # FIELDS, plus the title under TITLE_FIELD. Multi-value fields (keywords
      # and the like) come back joined, because that is how the DAM stores a
      # metadata value and how its filters read one.
      def metadata_for(refs)
        return {} if refs.blank?

        rows = @client.query(<<~SQL, refs, [TITLE_FIELD, *FIELDS.keys])
          SELECT rn.resource AS ref, f.name AS field, n.name AS value
          FROM resource_node rn
          JOIN node n ON n.ref = rn.node
          JOIN resource_type_field f ON f.ref = n.resource_type_field
          WHERE rn.resource IN (%s) AND f.name IN (%s) AND n.name <> ''
          ORDER BY rn.resource, f.ref, n.order_by
        SQL

        collected = rows.each_with_object({}) do |row, gathered|
          bucket = gathered[row['ref'].to_i] ||= Hash.new { |hash, key| hash[key] = [] }
          bucket[row['field']] << row['value'].to_s.strip
        end
        collected.transform_values { |fields| fields.transform_values { |values| values.uniq.join(', ') } }
      end

      # { resource_ref => [collection name, ...] }, for rebuilding the
      # groupings people already curated.
      def collections_for(refs)
        return {} if refs.blank?

        rows = @client.query(<<~SQL, refs)
          SELECT cr.resource AS ref, c.name AS name
          FROM collection_resource cr
          JOIN collection c ON c.ref = cr.collection
          WHERE cr.resource IN (%s) AND c.name <> ''
          ORDER BY c.name
        SQL

        rows.group_by { |row| row['ref'].to_i }
            .transform_values { |grouped| grouped.map { |row| row['name'].to_s }.uniq }
      end
    end
  end
end
