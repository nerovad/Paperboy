# frozen_string_literal: true

[
  'AlarmRawdata',
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
      name: 'gsa_security'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/alarm_rawdata.csv',
      local: 'alarm_rawdata.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['accountid',    'accountid',    'nvarchar(max)', 'NULL', nil],
      ['note',         'note',         'nvarchar(max)', 'NULL', nil],
      ['name',         'name',         'nvarchar(max)', 'NULL', nil],
      ['address',      'address',      'nvarchar(max)', 'NULL', nil],
      ['description',  'description',  'nvarchar(max)', 'NULL', nil],
      ['code',         'code',         'nvarchar(max)', 'NULL', nil],
      ['acctlinecode', 'acctlinecode', 'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'alarm_rawdata',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
