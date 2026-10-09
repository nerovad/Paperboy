# frozen_string_literal: true

[
  'Gsa_scan_timetracking_event',
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
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'TimeTracking_Event',
      local: 'gsa_scan_timetracking_event.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['ProjectName', 'ProjectName', 'nvarchar(100)', 'NOT NULL', nil],
      ['CardProject', 'CardProject', 'nvarchar(100)', 'NULL', nil],
      ['UniqueID', 'UniqueID', 'varchar(30)', 'NOT NULL', nil],
      ['BoxNumber', 'BoxNumber', 'varchar(20)', 'NOT NULL', nil],
      ['EventType', 'EventType', 'varchar(20)', 'NOT NULL', nil],
      ['Date', 'Date', 'date', 'NOT NULL', nil],
      ['StartTime', 'StartTime', 'time(0)', 'NULL', nil],
      ['EndTime', 'EndTime', 'time(0)', 'NULL', nil],
      ['Operator', 'Operator', 'nvarchar(50)', 'NULL', nil],
      ['AmPmSource', 'AmPmSource', 'varchar(10)', 'NULL', nil],
      ['SourceFile', 'SourceFile', 'nvarchar(260)', 'NULL', nil],
      ['PageNo', 'PageNo', 'int', 'NULL', nil],
      ['CardSerial', 'CardSerial', 'varchar(30)', 'NULL', nil],
      ['ReviewStatus', 'ReviewStatus', 'varchar(20)', 'NOT NULL', nil],
      ['Notes', 'Notes', 'nvarchar(1000)', 'NULL', nil],
      ['ExtractedAt', 'ExtractedAt', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'TimeTracking_Event',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
