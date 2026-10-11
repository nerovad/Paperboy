# frozen_string_literal: true

[
  'Gsarecords_oneil',
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
      name: 'gsarecords'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSARecords',
      schema: 'dbo',
      table: 'ONeil',
      local: 'gsarecords_oneil.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['AccountCode', 'AccountCode', 'nvarchar(50)', 'NOT NULL', nil],
      ['InvoiceNumber', 'InvoiceNumber', 'smallint', 'NOT NULL', nil],
      ['Date', 'Date', 'date', 'NOT NULL', nil],
      ['TransactionDescription', 'TransactionDescription', 'nvarchar(50)', 'NOT NULL', nil],
      ['ActionCode', 'ActionCode', 'nvarchar(50)', 'NOT NULL', nil],
      ['Rate', 'Rate', 'float', 'NOT NULL', nil],
      ['Quantity', 'Quantity', 'float', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'rcd',
        table: 'ONeil',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
