# frozen_string_literal: true

[
  'Gsa_scan_timetrackingsession',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsa_scan'
    },
    dependency: %w[Gsa_scan_boxstatusemployee Gsa_scan_timetrackingactivity Gsa_scan_job],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'TimeTrackingSession',
      local: 'gsa_scan_timetrackingsession.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['SessionID', 'SessionID', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['EmployeeID', 'EmployeeID', 'int', 'NOT NULL', nil],
      ['Activity', 'Activity', 'nvarchar(40)', 'NOT NULL', nil],
      ['BoxIdentifier', 'BoxIdentifier', 'nvarchar(120)', 'NOT NULL', nil],
      ['Comment', 'Comment', 'nvarchar(1000)', 'NOT NULL', nil],
      ['State', 'State', 'varchar(12)', 'NOT NULL', nil],
      ['StartedAtUtc', 'StartedAtUtc', 'datetime2(3)', 'NOT NULL', nil],
      ['EndedAtUtc', 'EndedAtUtc', 'datetime2(3)', 'NULL', nil],
      ['Version', 'Version', 'int', 'NOT NULL', nil],
      ['JobID', 'JobID', 'varchar(50)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'TimeTrackingSession',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
