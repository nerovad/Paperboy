# frozen_string_literal: true

[
  'Funds',
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
      url: 'http://acweb/cutoff/WP Fund on AUD Web Page.xlsx',
      location: 'funds.xlsx',
      local: 'funds.xlsx',
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

      [ 'fiscal_year',   nil,             'nvarchar(4)',   'NOT NULL', nil ],
      [ 'fund_code',     'fund_id',       'nvarchar(3)',   'NOT NULL', nil ],
      [ 'long_name',     'long_name',     'nvarchar(100)', 'NOT NULL', nil ],
      [ 'short_name',    'short_name',    'nvarchar(50)',  'NOT NULL', nil ],
      [ 'fund_class',    'fund_class',    'nvarchar(50)',  'NOT NULL', nil ],
      [ 'fund_category', 'fund_category', 'nvarchar(50)',  'NOT NULL', nil ],
      [ 'fund_type',     'fund_type',     'nvarchar(50)',  'NOT NULL', nil ],
      [ 'fund_group',    'fund_group',    'nvarchar(50)',  'NOT NULL', nil ],
      [ 'cafr_type',     'cafr_type',     'nvarchar(50 )', 'NOT NULL', nil ],
      [ 'active',        'active',        'bit',           'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'funds',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
