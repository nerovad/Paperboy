# frozen_string_literal: true

[
  'Gsa_scan_jobboxlist',
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
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'JobBoxList',
      local: 'gsa_scan_jobboxlist.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['BoxNumber', 'BoxNumber', 'varchar(20)', 'NOT NULL', nil],
      ['ProjectName', 'ProjectName', 'nvarchar(100)', 'NOT NULL', nil],
      ['AccountCode', 'AccountCode', 'nvarchar(100)', 'NULL', nil],
      ['Description', 'Description', 'nvarchar(400)', 'NULL', nil],
      ['AddDate', 'AddDate', 'date', 'NULL', nil],
      ['RecordSeriesCode', 'RecordSeriesCode', 'varchar(20)', 'NULL', nil],
      ['RecordSeriesTitle', 'RecordSeriesTitle', 'nvarchar(200)', 'NULL', nil],
      ['UDF1', 'UDF1', 'nvarchar(200)', 'NULL', nil],
      ['UDF2', 'UDF2', 'nvarchar(200)', 'NULL', nil],
      ['UDF3', 'UDF3', 'nvarchar(200)', 'NULL', nil],
      ['UDF4', 'UDF4', 'nvarchar(200)', 'NULL', nil],
      ['SourceFile', 'SourceFile', 'nvarchar(260)', 'NULL', nil],
      ['ImportedAt', 'ImportedAt', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'JobBoxList',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
