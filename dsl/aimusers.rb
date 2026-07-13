# frozen_string_literal: true

[
  'Aimusers',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/aimusers.csv',
      local: 'aimusers.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['employeeid',               'employeeid',               'nvarchar(max)', 'NULL', nil],
      ['firstname',                'firstname',                'nvarchar(max)', 'NULL', nil],
      ['lastname',                 'lastname',                 'nvarchar(max)', 'NULL', nil],
      ['email',                    'email',                    'nvarchar(max)', 'NULL', nil],
      ['created',                  'created',                  'nvarchar(max)', 'NULL', nil],
      ['updated',                  'updated',                  'nvarchar(max)', 'NULL', nil],
      ['lastlogin',                'lastlogin',                'nvarchar(max)', 'NULL', nil],
      ['active',                   'active',                   'nvarchar(max)', 'NULL', nil],
      ['licensetype',              'licensetype',              'nvarchar(max)', 'NULL', nil],
      ['systemadmininistrator',    'systemadmininistrator',    'nvarchar(max)', 'NULL', nil],
      ['applicationadministrator', 'applicationadministrator', 'nvarchar(max)', 'NULL', nil],
      ['applicationsupervisor',    'applicationsupervisor',    'nvarchar(max)', 'NULL', nil],
      ['externaladministrator',    'externaladministrator',    'nvarchar(max)', 'NULL', nil],
      ['externalsupervisor',       'externalsupervisor',       'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'aimusers',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
