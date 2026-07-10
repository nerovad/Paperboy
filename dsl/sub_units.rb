# frozen_string_literal: true

[
  'SubUnits',
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
      url: 'http://acweb/cutoff/WP Sub Unit on AUD Web Page.xlsx',
      location: 'sub_units.xlsx',
      local: 'sub_units.xlsx',
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

      [ 'fiscal_year',   nil,             'nvarchar(4)',  'NOT NULL', nil ],
      [ 'department',    'agency_id',     'nvarchar(3)',  'NOT NULL', nil ],
      [ 'unit_code',     'unit_id',       'nvarchar(4)',  'NOT NULL', nil ],
      [ 'sub_unit_code', 'sub_unit_id',   'nvarchar(4)',  'NOT NULL', nil ],
      [ 'sub_unit_name', 'sub_unit_name', 'nvarchar(50)', 'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'sub_units',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
