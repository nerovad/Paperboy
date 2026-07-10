# frozen_string_literal: true

[
  'AgencyRevenues',
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
      url: 'http://acweb/cutoff/WP Department Revenue Source on AUD Web Page.xlsx',
      location: 'agency_revenues.xlsx',
      local: 'agency_revenues.xlsx',
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

      [ 'fiscal_year',  nil,            'nvarchar(4)',   'NOT NULL', nil ],
      [ 'department',   'agency_id',    'nvarchar(3)',   'NOT NULL', nil ],
      [ 'revenue_code', 'revenue_code', 'nvarchar(4)',   'NOT NULL', nil ],
      [ 'long_name',    'long_name',    'nvarchar(100)', 'NOT NULL', nil ],
      [ 'short_name',   'short_name',   'nvarchar(10)',  'NOT NULL', nil ],
      [ 'active',       'active',       'bit',           'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'agency_revenues',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
