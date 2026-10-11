# frozen_string_literal: true

[
  'Gsabss_agencies',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'agencies',
      local: 'gsabss_agencies.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil],
      ['name', 'name', 'nvarchar(100)', 'NOT NULL', nil],
      ['long_name', 'long_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['short_name', 'short_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'agencies',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
