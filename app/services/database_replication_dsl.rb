# frozen_string_literal: true

class DatabaseReplicationDsl
  def self.render(preview)
    <<~RUBY
      # frozen_string_literal: true

      [
        #{preview.table.sub(/\A./, &:upcase).inspect},
        {
          steps: {
            manual: { enabled: true, steps: Workflow::MANUAL_STEPS },
            scheduled: { enabled: true, frequency: :daily, steps: Workflow::SCHEDULED_STEPS }
          },
          source: {
            host: #{preview.server.inspect},
            database: #{preview.database.inspect},
            schema: #{preview.schema.inspect},
            table: #{preview.table.inspect},
            local: #{"#{preview.table}.csv".inspect},
            format: :csv,
            strategy: :replicate
          },
          to_csv: { sheet: 0, header_row: 0, data_row: 1 },
          header: [
          ],
          database_connections: [
            {
              host: #{preview.target_server.inspect},
              database: #{preview.target_database.inspect},
              schema: #{preview.target_schema.inspect},
              table: #{preview.target_table.inspect},
              inject: { mode: :truncate_insert }
            }
          ]
        }
      ]
    RUBY
  end
end
