# frozen_string_literal: true

[
  'Gsa_scan_calsaws_prepsession',
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
      table: 'CalSAWS_PrepSession',
      local: 'gsa_scan_calsaws_prepsession.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Date', 'Date', 'date', 'NOT NULL', nil],
      ['TubType', 'TubType', 'varchar(10)', 'NOT NULL', nil],
      ['StartTime', 'StartTime', 'time(0)', 'NOT NULL', nil],
      ['EndTime', 'EndTime', 'time(0)', 'NOT NULL', nil],
      ['Operator', 'Operator', 'varchar(10)', 'NOT NULL', nil],
      ['RawStartTime', 'RawStartTime', 'nvarchar(30)', 'NOT NULL', nil],
      ['RawEndTime', 'RawEndTime', 'nvarchar(30)', 'NOT NULL', nil],
      ['StartAmPm', 'StartAmPm', 'varchar(2)', 'NULL', nil],
      ['EndAmPm', 'EndAmPm', 'varchar(2)', 'NULL', nil],
      ['StartTimeSource', 'StartTimeSource', 'varchar(15)', 'NOT NULL', nil],
      ['EndTimeSource', 'EndTimeSource', 'varchar(15)', 'NOT NULL', nil],
      ['SourceFile', 'SourceFile', 'nvarchar(260)', 'NOT NULL', nil],
      ['SourceHash', 'SourceHash', 'char(64)', 'NOT NULL', nil],
      ['PageNo', 'PageNo', 'int', 'NOT NULL', nil],
      ['RowNo', 'RowNo', 'int', 'NOT NULL', nil],
      ['ReviewStatus', 'ReviewStatus', 'varchar(20)', 'NOT NULL', nil],
      ['Notes', 'Notes', 'nvarchar(1000)', 'NULL', nil],
      ['ExtractedAt', 'ExtractedAt', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'CalSAWS_PrepSession',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
