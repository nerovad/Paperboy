# frozen_string_literal: true

[
  'Gsabss_printers',
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
      table: 'printers',
      local: 'gsabss_printers.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['printer', 'printer', 'nvarchar(max)', 'NOT NULL', nil],
      ['ip', 'ip', 'nvarchar(max)', 'NOT NULL', nil],
      ['rip_type', 'rip_type', 'nvarchar(max)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'printers',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
