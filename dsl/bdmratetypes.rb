# frozen_string_literal: true

[
  'Bdmratetypes',
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
      local: 'bdmratetypes.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'bdmratetypes.csv',
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['rateid',      'rateid',      'smallint',      'NOT NULL', nil],
      ['description', 'description', 'nvarchar(150)', 'NOT NULL', nil],
      ['uom',         'uom',         'nvarchar(15)',  'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'bdmratetypes',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
