# frozen_string_literal: true

[
  'Bdmrates',
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
      name: 'budget_rate_development'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/bdmrates.xlsx',
      local: 'bdmrates.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'bdmrates.csv',
    to_csv: {
      sheet: 1,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['fyear',    'fyear',    'nvarchar(4)', 'NOT NULL', nil],
      ['rateid',   'rateid',   'smallint',    'NOT NULL', nil],
      ['objectid', 'objectid', 'smallint',    'NOT NULL', nil],
      ['rate',     'rate',     'float',       'NOT NULL', nil],
      ['unitid',   'unitid',   'smallint',    'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'bdmrates',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
