# frozen_string_literal: true

[
  'Gsa_scan_universal_data_import',
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
      table: 'Universal_Data_Import',
      local: 'gsa_scan_universal_data_import.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Key', 'Key', 'nvarchar(100)', 'NOT NULL', nil],
      ['Value_001', 'Value_001', 'nvarchar(max)', 'NULL', nil],
      ['Value_002', 'Value_002', 'nvarchar(max)', 'NULL', nil],
      ['Value_003', 'Value_003', 'nvarchar(max)', 'NULL', nil],
      ['Value_004', 'Value_004', 'nvarchar(max)', 'NULL', nil],
      ['Value_005', 'Value_005', 'nvarchar(max)', 'NULL', nil],
      ['Value_006', 'Value_006', 'nvarchar(max)', 'NULL', nil],
      ['Value_007', 'Value_007', 'nvarchar(max)', 'NULL', nil],
      ['Value_008', 'Value_008', 'nvarchar(max)', 'NULL', nil],
      ['Value_009', 'Value_009', 'nvarchar(max)', 'NULL', nil],
      ['Value_010', 'Value_010', 'nvarchar(max)', 'NULL', nil],
      ['Value_011', 'Value_011', 'nvarchar(max)', 'NULL', nil],
      ['Value_012', 'Value_012', 'nvarchar(max)', 'NULL', nil],
      ['Value_013', 'Value_013', 'nvarchar(max)', 'NULL', nil],
      ['Value_014', 'Value_014', 'nvarchar(max)', 'NULL', nil],
      ['Value_015', 'Value_015', 'nvarchar(max)', 'NULL', nil],
      ['Value_016', 'Value_016', 'nvarchar(max)', 'NULL', nil],
      ['Value_017', 'Value_017', 'nvarchar(max)', 'NULL', nil],
      ['Value_018', 'Value_018', 'nvarchar(max)', 'NULL', nil],
      ['Value_019', 'Value_019', 'nvarchar(max)', 'NULL', nil],
      ['Value_020', 'Value_020', 'nvarchar(max)', 'NULL', nil],
      ['Value_021', 'Value_021', 'nvarchar(max)', 'NULL', nil],
      ['Value_022', 'Value_022', 'nvarchar(max)', 'NULL', nil],
      ['Value_023', 'Value_023', 'nvarchar(max)', 'NULL', nil],
      ['Value_024', 'Value_024', 'nvarchar(max)', 'NULL', nil],
      ['Value_025', 'Value_025', 'nvarchar(max)', 'NULL', nil],
      ['Date_Value_01', 'Date_Value_01', 'date', 'NULL', nil],
      ['Date_Value_02', 'Date_Value_02', 'date', 'NULL', nil],
      ['Date_Value_03', 'Date_Value_03', 'date', 'NULL', nil],
      ['Date_Value_04', 'Date_Value_04', 'date', 'NULL', nil],
      ['Date_Value_05', 'Date_Value_05', 'date', 'NULL', nil],
      ['Project', 'Project', 'nvarchar(100)', 'NULL', nil],
      ['JobID', 'JobID', 'nvarchar(100)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Universal_Data_Import',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
