# frozen_string_literal: true

[
  'Gsa_scan_ovs_scanlog',
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
      table: 'OVS_ScanLog',
      local: 'gsa_scan_ovs_scanlog.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ScannerSN', 'ScannerSN', 'varchar(40)', 'NOT NULL', nil],
      ['ScanNo', 'ScanNo', 'bigint', 'NOT NULL', nil],
      ['ScanTime', 'ScanTime', 'datetime2(0)', 'NOT NULL', nil],
      ['Machine', 'Machine', 'varchar(50)', 'NULL', nil],
      ['ScanUser', 'ScanUser', 'varchar(50)', 'NULL', nil],
      ['Account', 'Account', 'nvarchar(100)', 'NULL', nil],
      ['Length', 'Length', 'decimal(9,2)', 'NULL', nil],
      ['Width', 'Width', 'decimal(9,2)', 'NULL', nil],
      ['Dpi', 'Dpi', 'int', 'NULL', nil],
      ['ImageType', 'ImageType', 'varchar(30)', 'NULL', nil],
      ['FilePath', 'FilePath', 'nvarchar(400)', 'NULL', nil],
      ['FileName', 'FileName', 'nvarchar(255)', 'NULL', nil],
      ['FileType', 'FileType', 'varchar(10)', 'NULL', nil],
      ['SourceFile', 'SourceFile', 'nvarchar(200)', 'NULL', nil],
      ['LoadedAt', 'LoadedAt', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'OVS_ScanLog',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
