# frozen_string_literal: true

[
  'Tc60Services',
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
      name: 'billing_configuration'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/tc60_services.csv',
      local: 'tc60_services.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['year',      'year',      'nvarchar(4)',  'NOT NULL', nil],
      ['type',      'type',      'nvarchar(3)',  'NOT NULL', nil],
      ['service',   'service',   'nvarchar(15)', 'NOT NULL', nil],
      ['sunit',     'sunit',     'nvarchar(4)',  'NOT NULL', nil],
      ['sobject',   'sobject',   'int',          'NOT NULL', nil],
      ['sactivity', 'sactivity', 'nvarchar(4)',  'NOT NULL', nil],
      ['sfunction', 'sfunction', 'nvarchar(4)',  'NOT NULL', nil],
      ['sprogram',  'sprogram',  'nvarchar(10)', 'NOT NULL', nil],
      ['sphase',    'sphase',    'nvarchar(6)',  'NULL',     nil],
      ['stask',     'stask',     'nvarchar(4)',  'NULL',     nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'tc60_services',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
