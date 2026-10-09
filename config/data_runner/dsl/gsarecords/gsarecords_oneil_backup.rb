# frozen_string_literal: true

[
  'Gsarecords_oneil_backup',
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
      name: 'gsarecords'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSARecords',
      schema: 'dbo',
      table: 'ONeil_Backup',
      local: 'gsarecords_oneil_backup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['AccountCode', 'AccountCode', 'nvarchar(50)', 'NULL', nil],
      ['InvoiceNumber', 'InvoiceNumber', 'smallint', 'NULL', nil],
      ['Date', 'Date', 'nvarchar(50)', 'NULL', nil],
      ['TransactionDescription', 'TransactionDescription', 'nvarchar(50)', 'NULL', nil],
      ['ActionCode', 'ActionCode', 'nvarchar(50)', 'NULL', nil],
      ['Rate', 'Rate', 'float', 'NULL', nil],
      ['Quantity', 'Quantity', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'rcd',
        table: 'ONeil_Backup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
