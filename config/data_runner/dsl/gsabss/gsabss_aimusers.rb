# frozen_string_literal: true

[
  'Gsabss_aimusers',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'aimusers',
      local: 'gsabss_aimusers.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['employeeid', 'employeeid', 'nvarchar(max)', 'NULL', nil],
      ['firstname', 'firstname', 'nvarchar(max)', 'NULL', nil],
      ['lastname', 'lastname', 'nvarchar(max)', 'NULL', nil],
      ['email', 'email', 'nvarchar(max)', 'NULL', nil],
      ['created', 'created', 'nvarchar(max)', 'NULL', nil],
      ['updated', 'updated', 'nvarchar(max)', 'NULL', nil],
      ['lastlogin', 'lastlogin', 'nvarchar(max)', 'NULL', nil],
      ['active', 'active', 'nvarchar(max)', 'NULL', nil],
      ['licensetype', 'licensetype', 'nvarchar(max)', 'NULL', nil],
      ['systemadmininistrator', 'systemadmininistrator', 'nvarchar(max)', 'NULL', nil],
      ['applicationadministrator', 'applicationadministrator', 'nvarchar(max)', 'NULL', nil],
      ['applicationsupervisor', 'applicationsupervisor', 'nvarchar(max)', 'NULL', nil],
      ['externaladministrator', 'externaladministrator', 'nvarchar(max)', 'NULL', nil],
      ['externalsupervisor', 'externalsupervisor', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'aimusers',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
