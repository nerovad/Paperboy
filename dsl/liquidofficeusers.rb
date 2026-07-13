# frozen_string_literal: true

[
  'Liquidofficeusers',
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
      name: 'user_entitlements'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/liquidofficeusers.csv',
      local: 'liquidofficeusers.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['loginid',       'loginid',       'nvarchar(max)', 'NULL', nil],
      ['firstname',     'firstname',     'nvarchar(max)', 'NULL', nil],
      ['lastname',      'lastname',      'nvarchar(max)', 'NULL', nil],
      ['lastlogondate', 'lastlogondate', 'nvarchar(max)', 'NULL', nil],
      ['logoncount',    'logoncount',    'nvarchar(max)', 'NULL', nil],
      ['serverid',      'serverid',      'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'liquidofficeusers',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
