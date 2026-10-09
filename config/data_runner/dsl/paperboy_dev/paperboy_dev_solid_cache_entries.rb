# frozen_string_literal: true

[
  'Paperboy_dev_solid_cache_entries',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'solid_cache_entries',
      local: 'paperboy_dev_solid_cache_entries.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'varbinary(max)', 'NOT NULL', nil],
      ['value', 'value', 'varbinary(max)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['key_hash', 'key_hash', 'bigint', 'NOT NULL', nil],
      ['byte_size', 'byte_size', 'int', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_cache_entries',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
