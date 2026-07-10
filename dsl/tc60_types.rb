# frozen_string_literal: true

[
  'Tc60Types',
  {
    steps: {
      enabled: false,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'billing_configuration'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/tc60_types.csv',
      local: 'tc60_types.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'type',         'type',         'nvarchar(3)',  'NULL', nil ],
      [ 'active',       'active',       'bit',          'NULL', nil ],
      [ 'name',         'name',         'nvarchar(30)', 'NULL', nil ],
      [ 'funding_type', 'funding_type', 'nvarchar(10)', 'NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'tc60_types',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
