# frozen_string_literal: true

[
  'Gsa_scan_timetrackingaudit',
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
      name: 'gsa_scan'
    },
    dependency: %w[Gsa_scan_boxstatusemployee Gsa_scan_timetrackingsession],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'TimeTrackingAudit',
      local: 'gsa_scan_timetrackingaudit.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['AuditID', 'AuditID', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['SessionID', 'SessionID', 'bigint', 'NOT NULL', nil],
      ['Action', 'Action', 'varchar(12)', 'NOT NULL', nil],
      ['Reason', 'Reason', 'nvarchar(1000)', 'NOT NULL', nil],
      ['ChangedAtUtc', 'ChangedAtUtc', 'datetime2(3)', 'NOT NULL', nil],
      ['EmployeeID', 'EmployeeID', 'int', 'NOT NULL', nil],
      ['MachineName', 'MachineName', 'nvarchar(128)', 'NOT NULL', nil],
      ['WindowsIdentity', 'WindowsIdentity', 'nvarchar(256)', 'NOT NULL', nil],
      ['BeforeJSON', 'BeforeJSON', 'nvarchar(max)', 'NULL', nil],
      ['AfterJSON', 'AfterJSON', 'nvarchar(max)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'TimeTrackingAudit',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
