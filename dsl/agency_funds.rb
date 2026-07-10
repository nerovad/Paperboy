# frozen_string_literal: true

[
  'AgencyFunds',
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
      url: 'http://acweb/cutoff/WP Valid Fund Dept on AUD Web Page.xlsx',
      location: 'agency_funds.xlsx',
      local: 'agency_funds.xlsx',
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

      [ 'fiscal_year', nil,         'nvarchar(4)', 'NOT NULL', nil ],
      [ 'fund_code',   'fund_id',   'nvarchar(3)', 'NOT NULL', nil ],
      [ 'department',  'agency_id', 'nvarchar(3)', 'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'agency_funds',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
