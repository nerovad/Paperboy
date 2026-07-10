# frozen_string_literal: true

[
  'RevenueSources',
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
      url: 'http://acweb/cutoff/WP Revenue Source on AUD Web Page.xlsx',
      location: 'revenue_sources.xlsx',
      local: 'revenue_sources.xlsx',
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

      [ 'fiscal_year',  nil,                 'nvarchar(4)',   'NOT NULL', nil ],
      [ 'revenue_code', 'revenue_source_id', 'int',           'NOT NULL', nil ],
      [ 'long_name',    'long_name',         'nvarchar(100)', 'NOT NULL', nil ],
      [ 'short_name',   'short_name',        'nvarchar(50)',  'NOT NULL', nil ],
      [ 'active',       'active',            'bit',           'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'revenue_sources',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
