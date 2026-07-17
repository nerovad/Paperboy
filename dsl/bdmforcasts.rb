# frozen_string_literal: true

[
  'Bdmforcasts',
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
      local: 'bdmforcasts.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'bdmforcasts.csv',
    to_csv: {
      sheet: 2,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['fyear',          'fyear',          'nvarchar(4)',  'NOT NULL', nil],
      ['unitid',         'unit_id',        'smallint',     'NOT NULL', nil],
      ['programid',      'program_id',     'nvarchar(10)', 'NOT NULL', nil],
      ['percent_growth', 'percent_growth', 'float',        'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'bdmforcasts',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
