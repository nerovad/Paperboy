# frozen_string_literal: true

[
  'Functions',
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
      url: 'http://acweb/cutoff/WP Function on AUD Web Page.xlsx',
      location: 'functions.xlsx',
      local: 'functions.xlsx',
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
      [ 'fiscal_year',   nil, 'nvarchar(4)',   'NOT NULL', nil ],
      [ 'department',    'agency_id',   'nvarchar(3)',   'NOT NULL', nil ],
      [ 'function_code', 'function_id', 'nvarchar(4)',   'NULL',     nil ],
      [ 'long_name',     'long_name',   'nvarchar(100)', 'NULL',     nil ],
      [ 'short_name',    'short_name',  'nvarchar(50)',  'NULL',     nil ],
      [ 'active',        'active',      'bit',           'NOT NULL', nil ]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'functions',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
