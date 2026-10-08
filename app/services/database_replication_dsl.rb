# frozen_string_literal: true

require 'fileutils'

class DatabaseReplicationDsl
  class AlreadyExists < StandardError; end

  STEPS = %i[download to_csv use_dsl inject].freeze

  def self.group_name(database)
    database.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
  end

  def self.table_slug(table)
    table.to_s.split('.', 2).last.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
  end

  def self.slug_for(database, table)
    "#{group_name(database)}_#{table_slug(table)}"
  end

  def self.write!(preview, root)
    path = Pathname.new(root).join(preview.group, "#{preview.slug}.rb")
    raise AlreadyExists, 'A DSL for this table already exists.' if path.file?

    conflict = DslCatalog.entries.find { |entry| entry.slug == preview.slug || entry.key == preview.key }
    raise AlreadyExists, "DSL #{preview.slug} already exists." if conflict

    FileUtils.mkdir_p(path.dirname)
    File.write(path, render(preview))
    path
  end

  def self.render(preview)
    <<~RUBY
      # frozen_string_literal: true

      [
        #{ruby_string(preview.key)},
        {
          steps: {
            manual: { enabled: true, steps: %i[#{STEPS.join(' ')}] },
            scheduled: { enabled: true, frequency: :daily, steps: %i[#{STEPS.join(' ')}] }
          },
          group: {
            name: #{ruby_string(preview.group)}
          },
          source: {
            host: #{ruby_string(preview.server)},
            database: #{ruby_string(preview.database)},
            schema: #{ruby_string(preview.schema)},
            table: #{ruby_string(preview.table)},
            local: #{ruby_string(preview.local)},
            format: :csv,
            strategy: :replicate
          },
          to_csv: { sheet: 0, header_row: 0, data_row: 1 },
          header: [
      #{header_lines(preview)}
          ],
          database_connections: [
            {
              host: #{ruby_string(preview.target_server)},
              database: #{ruby_string(preview.target_database)},
              schema: #{ruby_string(preview.target_schema)},
              table: #{ruby_string(preview.target_table)},
              inject: { mode: :truncate_insert }
            }
          ]
        }
      ]
    RUBY
  end

  def self.header_lines(preview)
    preview.headers.map { |column| header_row(column) }.join(",\n")
  end

  def self.header_row(column)
    values = [column[:name], column[:name], column[:data_type], column[:nullability]]
    "      [#{values.map { |value| ruby_string(value) }.join(', ')}, nil]"
  end

  def self.ruby_string(value)
    escaped = value.to_s.gsub('\\') { '\\\\' }.gsub("'") { "\\'" }
    "'#{escaped}'"
  end
end
