# frozen_string_literal: true

[
  'ZyzzyvaUnits',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/zyzzyva_units.xlsx',
      local: 'zyzzyva_units.xlsx',
      format: :xlsx,
      strategy: :append
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    use_dsl: {
      dedup: true
    },
    header: [

      ['fiscal_year', nil,             'nvarchar(4)',   'NOT NULL', nil],
      ['department',  'agency_id',     'nvarchar(3)',   'NOT NULL', nil],
      ['division',    'division_id',   'nvarchar(4)',   'NOT NULL', nil],
      ['group_code',  'department_id', 'nvarchar(4)',   'NOT NULL', nil],
      ['unit',        'unit_id',       'nvarchar(4)',   'NOT NULL', nil],
      ['long_name',   'long_name',     'nvarchar(100)', 'NOT NULL', nil],
      ['short_name',  'short_name',    'nvarchar(50)',  'NOT NULL', nil],
      ['active',      'active',        'bit',           'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'units',
        inject: {
          mode: :append
        }
      }
    ]
  }
]
