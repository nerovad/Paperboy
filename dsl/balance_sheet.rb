# frozen_string_literal: true

[
  'BalanceSheet',
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
      name: 'chart_of_accounts'
    },
    source: {
      url: 'http://acweb/cutoff/WP Balance Sheet Account on AUD Web Page.xlsx',
      location: 'balance_sheet.xlsx',
      local: 'balance_sheet.xlsx',
      format: :xlsx,
      strategy: :http
    },
    to_csv: {
      sheet: 0,
      header_row: 6,
      data_row: 7
    },
    use_dsl: {
      dedup: true
    },
    header: [

      ['fiscal_year',                       nil,                                 'nvarchar(4)',   'NOT NULL', nil],
      ['balance_sheet_account_code',        'balance_sheet_account_code',        'nvarchar(4)',   'NOT NULL', nil],
      ['balance_sheet_account_name',        'balance_sheet_account_name',        'nvarchar(100)', 'NOT NULL', nil],
      ['balance_sheet_account_short_name',  'balance_sheet_account_short_name',  'nvarchar(50)',  'NOT NULL', nil],
      ['balance_sheet_account_description', 'balance_sheet_account_description', 'nvarchar(100)', 'NOT NULL', nil],
      ['active',                            'active',                            'bit',           'NOT NULL', nil],
      ['bsg_cd',                            'bsg_cd',                            'nvarchar(10)',  'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'balance_sheet',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
