# frozen_string_literal: true

[
  'Gsabss_workweeks',
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
      table: 'workweeks',
      local: 'gsabss_workweeks.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'nvarchar(max)', 'NULL', nil],
      ['year', 'year', 'nvarchar(max)', 'NULL', nil],
      ['work_week', 'work_week', 'nvarchar(max)', 'NULL', nil],
      ['start_date', 'start_date', 'nvarchar(max)', 'NULL', nil],
      ['end_date', 'end_date', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'workweeks',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
