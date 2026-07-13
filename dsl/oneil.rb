# frozen_string_literal: true

[
  'ONeil',
  {
    steps: {
      enabled: true,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'billing'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/oneil.csv',
      local: 'oneil.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['account_code',                 'AccountCode',            'nvarchar(50)', 'NOT NULL', nil],
      ['invoice_number',               'InvoiceNumber',          'int',          'NOT NULL', nil],
      ['update_date',                  'Date',                   'date',         'NOT NULL', nil],
      ['transaction_description',      'TransactionDescription', 'nvarchar(50)', 'NOT NULL', nil],
      ['action_code',                  'ActionCode',             'nvarchar(50)', 'NOT NULL', nil],
      ['actual_rate',                  'Rate',                   'float',        'NOT NULL', nil],
      ['subaccount_adjusted_quantity', 'Quantity',               'float',        'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSARecords',
        schema: 'dbo',
        table: '_stgONeil',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
