# frozen_string_literal: true

[
  'Gsa_scan_boxstatusevent',
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
    dependency: %w[Gsa_scan_boxstatuschoice Gsa_scan_boxstatusemployee Gsa_scan_job],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'BoxStatusEvent',
      local: 'gsa_scan_boxstatusevent.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['EventID', 'EventID', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['SubmissionID', 'SubmissionID', 'uniqueidentifier', 'NOT NULL', nil],
      ['BoxIdentifier', 'BoxIdentifier', 'nvarchar(120)', 'NOT NULL', nil],
      ['StatusID', 'StatusID', 'int', 'NOT NULL', nil],
      ['EmployeeID', 'EmployeeID', 'int', 'NOT NULL', nil],
      ['RecordedAtUtc', 'RecordedAtUtc', 'datetime2(3)', 'NOT NULL', nil],
      ['MachineName', 'MachineName', 'nvarchar(128)', 'NOT NULL', nil],
      ['WindowsIdentity', 'WindowsIdentity', 'nvarchar(256)', 'NOT NULL', nil],
      ['IsInaccurate', 'IsInaccurate', 'bit', 'NOT NULL', nil],
      ['InaccurateReason', 'InaccurateReason', 'nvarchar(1000)', 'NULL', nil],
      ['InaccurateAtUtc', 'InaccurateAtUtc', 'datetime2(3)', 'NULL', nil],
      ['InaccurateByEmployeeID', 'InaccurateByEmployeeID', 'int', 'NULL', nil],
      ['InaccurateMachineName', 'InaccurateMachineName', 'nvarchar(128)', 'NULL', nil],
      ['InaccurateWindowsIdentity', 'InaccurateWindowsIdentity', 'nvarchar(256)', 'NULL', nil],
      ['PrepWarningOverridden', 'PrepWarningOverridden', 'bit', 'NOT NULL', nil],
      ['JobID', 'JobID', 'varchar(50)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'BoxStatusEvent',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
