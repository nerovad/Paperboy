# frozen_string_literal: true

[
  'Fiscalmonths',
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
      name: 'human_resources'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/fiscalmonths.csv',
      local: 'fiscalmonths.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['apmon',  'apmon',  'nvarchar(4)', 'NOT NULL', nil],
      ['monnbr', 'monnbr', 'int',         'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'fiscalmonths',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
