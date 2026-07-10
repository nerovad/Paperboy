# frozen_string_literal: true

[
  'Appropriations',
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
      url: 'http://acweb/cutoff/WP Appropriation on AUD Web Page.xlsx',
      location: 'appropriations.xlsx',
      local: 'appropriations.xlsx',
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

      [ 'fiscal_year',              nil,                        'nvarchar(4)',   'NOT NULL', nil ],
      [ 'appropriation_unit',       'appropriation_unit',       'nvarchar(8)',   'NOT NULL', nil ],
      [ 'appropriation_name',       'appropriation_name',       'nvarchar(100)', 'NOT NULL', nil ],
      [ 'appropriation_short_name', 'appropriation_short_name', 'nvarchar(50)',  'NOT NULL', nil ],
      [ 'appropriation_class',      'appropriation_class',      'nvarchar(4)',   'NOT NULL', nil ],
      [ 'appropriation_category',   'appropriation_category',   'nvarchar(4)',   'NOT NULL', nil ],
      [ 'active',                   'active',                   'bit',           'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'appropriations',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
