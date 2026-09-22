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

      def initialize(client = Client.new)
        @client = client
      end

      def active_count
        @client.query("SELECT COUNT(*) AS n FROM resource WHERE archive = #{ACTIVE}").first['n'].to_i
      end

      # Resources in ref order, a page at a time, so 14,000 of them are never
      # held at once.
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

      # Every field that holds a value on at least one live resource, whatever
      # it is called. Fields nobody ever filled in are left behind: an empty
      # column on the Advanced Search picker helps nobody.
      def fields_in_use
        @client.query(<<~SQL)
          SELECT f.ref, f.name, f.title, f.type, COUNT(DISTINCT rn.resource) AS resources
          FROM resource_type_field f
          JOIN node n ON n.resource_type_field = f.ref
          JOIN resource_node rn ON rn.node = n.ref
          JOIN resource r ON r.ref = rn.resource AND r.archive = #{ACTIVE}
          WHERE n.name <> ''
          GROUP BY f.ref, f.name, f.title, f.type
          ORDER BY f.ref
        SQL
      end

      # { resource_ref => { field_name => "value, value" } }, every field.
      # Multi-value fields (keywords and the like) come back joined, because
      # that is how the DAM stores a metadata value and how its filters read
      # one.
      def metadata_for(refs)
        return {} if refs.blank?

        rows = @client.query(<<~SQL, refs)
          SELECT rn.resource AS ref, f.name AS field, n.name AS value
          FROM resource_node rn
          JOIN node n ON n.ref = rn.node
          JOIN resource_type_field f ON f.ref = n.resource_type_field
          WHERE rn.resource IN (%s) AND n.name <> ''
          ORDER BY rn.resource, f.ref, n.order_by
        SQL

        collected = rows.each_with_object({}) do |row, gathered|
          bucket = gathered[row['ref'].to_i] ||= Hash.new { |hash, key| hash[key] = [] }
          bucket[row['field']] << row['value'].to_s.strip
        end
        collected.transform_values { |fields| fields.transform_values { |values| values.uniq.join(', ') } }
      end

      # Every collection with the live resources in it, in the order people
      # arranged them, and the collection it sits inside.
      def collections
        members = @client.query(<<~SQL).group_by { |row| row['collection'].to_i }
          SELECT cr.collection, cr.resource
          FROM collection_resource cr
          JOIN resource r ON r.ref = cr.resource AND r.archive = #{ACTIVE}
          ORDER BY cr.collection, cr.sortorder, cr.resource
        SQL

        @client.query('SELECT ref, name, description, parent FROM collection ORDER BY ref').map do |row|
          { 'ref' => row['ref'].to_i, 'name' => row['name'].to_s, 'description' => row['description'].to_s,
            'parent' => row['parent'].presence&.to_i,
            'resources' => members.fetch(row['ref'].to_i, []).map { |member| member['resource'].to_i } }
        end
      end
    end
  end
end
