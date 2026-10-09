# frozen_string_literal: true

[
  'Gsabss_fiscalyears',
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
      table: 'fiscalyears',
      local: 'gsabss_fiscalyears.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['year', 'year', 'nvarchar(4)', 'NOT NULL', nil],
      ['sdate', 'sdate', 'date', 'NOT NULL', nil],
      ['edate', 'edate', 'date', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'fiscalyears',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
