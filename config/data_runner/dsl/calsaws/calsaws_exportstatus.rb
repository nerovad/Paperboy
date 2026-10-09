# frozen_string_literal: true

[
  'Calsaws_exportstatus',
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
      name: 'calsaws'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Calsaws',
      schema: 'dbo',
      table: 'ExportStatus',
      local: 'calsaws_exportstatus.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['Status', 'Status', 'nvarchar(50)', 'NULL', nil],
      ['Description', 'Description', 'nvarchar(50)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'calsaws',
        table: 'ExportStatus',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
