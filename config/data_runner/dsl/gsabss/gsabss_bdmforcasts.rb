# frozen_string_literal: true

[
  'Gsabss_bdmforcasts',
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
      table: 'bdmforcasts',
      local: 'gsabss_bdmforcasts.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['fyear', 'fyear', 'nvarchar(4)', 'NOT NULL', nil],
      ['unit_id', 'unit_id', 'smallint', 'NOT NULL', nil],
      ['program_id', 'program_id', 'nvarchar(10)', 'NOT NULL', nil],
      ['percent_growth', 'percent_growth', 'float', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'bdmforcasts',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
