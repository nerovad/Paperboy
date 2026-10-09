# frozen_string_literal: true

[
  'Gsabss_balance_sheet',
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
      table: 'balance_sheet',
      local: 'gsabss_balance_sheet.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['balance_sheet_account_code', 'balance_sheet_account_code', 'nvarchar(4)', 'NOT NULL', nil],
      ['balance_sheet_account_name', 'balance_sheet_account_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['balance_sheet_account_short_name', 'balance_sheet_account_short_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['balance_sheet_account_description', 'balance_sheet_account_description', 'nvarchar(100)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil],
      ['bsg_cd', 'bsg_cd', 'nvarchar(10)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'balance_sheet',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
