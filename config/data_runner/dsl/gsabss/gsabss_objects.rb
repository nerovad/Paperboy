# frozen_string_literal: true

[
  'Gsabss_objects',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'objects',
      local: 'gsabss_objects.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['object_id', 'object_id', 'int', 'NOT NULL', nil],
      ['long_name', 'long_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['short_name', 'short_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'objects',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
