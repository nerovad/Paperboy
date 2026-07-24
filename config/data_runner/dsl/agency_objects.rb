# frozen_string_literal: true

[
  'AgencyObjects',
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
      url: 'http://acweb/cutoff/WP Department Object on AUD Web Page.xlsx',
      location: 'agency_objects.xlsx',
      local: 'agency_objects.xlsx',
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

      ['fiscal_year',            nil,                  'nvarchar(4)',  'NOT NULL', nil],
      ['department',             'agency_id',          'nvarchar(3)',  'NOT NULL', nil],
      ['object_code',            'object_id',          'int',          'NOT NULL', nil],
      ['department_object_code', 'agency_object_code', 'nvarchar(4)',  'NOT NULL', nil],
      ['department_object_name', 'agency_object_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['rollup_object',          'rollup_object',      'nvarchar(50)', 'NOT NULL', nil],
      ['rollup_name',            'rollup_name',        'nvarchar(50)', 'NOT NULL', nil],
      ['active',                 'active',             'bit',          'NOT NULL', nil]

    ],

    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'agency_objects',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
