# frozen_string_literal: true

[
  'Gsabss_bdmrates',
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
      table: 'bdmrates',
      local: 'gsabss_bdmrates.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['fyear', 'fyear', 'nvarchar(4)', 'NOT NULL', nil],
      ['rateid', 'rateid', 'smallint', 'NOT NULL', nil],
      ['objectid', 'objectid', 'smallint', 'NOT NULL', nil],
      ['rate', 'rate', 'float', 'NOT NULL', nil],
      ['unitid', 'unitid', 'smallint', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'bdmrates',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
