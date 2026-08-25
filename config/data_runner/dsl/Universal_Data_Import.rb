# frozen_string_literal: true

[
  "Universal_Data_Import",
  {
    steps: {
      manual: { enabled: true, steps: Workflow::MANUAL_STEPS },
      scheduled: { enabled: true, frequency: :daily, steps: Workflow::SCHEDULED_STEPS }
    },
    source: {
      host: "10.135.204.161",
      database: "GSA Scan",
      schema: "dbo",
      table: "Universal_Data_Import",
      local: "Universal_Data_Import.csv",
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [

      ['id',            'id',            'int',           'IDENTITY(1,1) NOT NULL', nil],
      ['key',           'key',           'nvarchar(100)', 'NOT NULL',               nil],
      ['value_001',     'value_001',     'nvarchar(max)', 'NULL',                   nil],
      ['value_002',     'value_002',     'nvarchar(max)', 'NULL',                   nil],
      ['value_003',     'value_003',     'nvarchar(max)', 'NULL',                   nil],
      ['value_004',     'value_004',     'nvarchar(max)', 'NULL',                   nil],
      ['value_005',     'value_005',     'nvarchar(max)', 'NULL',                   nil],
      ['value_006',     'value_006',     'nvarchar(max)', 'NULL',                   nil],
      ['value_007',     'value_007',     'nvarchar(max)', 'NULL',                   nil],
      ['value_008',     'value_008',     'nvarchar(max)', 'NULL',                   nil],
      ['value_009',     'value_009',     'nvarchar(max)', 'NULL',                   nil],
      ['value_010',     'value_010',     'nvarchar(max)', 'NULL',                   nil],
      ['value_011',     'value_011',     'nvarchar(max)', 'NULL',                   nil],
      ['value_012',     'value_012',     'nvarchar(max)', 'NULL',                   nil],
      ['value_013',     'value_013',     'nvarchar(max)', 'NULL',                   nil],
      ['value_014',     'value_014',     'nvarchar(max)', 'NULL',                   nil],
      ['value_015',     'value_015',     'nvarchar(max)', 'NULL',                   nil],
      ['value_016',     'value_016',     'nvarchar(max)', 'NULL',                   nil],
      ['value_017',     'value_017',     'nvarchar(max)', 'NULL',                   nil],
      ['value_018',     'value_018',     'nvarchar(max)', 'NULL',                   nil],
      ['value_019',     'value_019',     'nvarchar(max)', 'NULL',                   nil],
      ['value_020',     'value_020',     'nvarchar(max)', 'NULL',                   nil],
      ['value_021',     'value_021',     'nvarchar(max)', 'NULL',                   nil],
      ['value_022',     'value_022',     'nvarchar(max)', 'NULL',                   nil],
      ['value_023',     'value_023',     'nvarchar(max)', 'NULL',                   nil],
      ['value_024',     'value_024',     'nvarchar(max)', 'NULL',                   nil],
      ['value_025',     'value_025',     'nvarchar(max)', 'NULL',                   nil],
      ['date_value_01', 'date_value_01', 'date',          'NULL',                   nil],
      ['date_value_02', 'date_value_02', 'date',          'NULL',                   nil],
      ['date_value_03', 'date_value_03', 'date',          'NULL',                   nil],
      ['date_value_04', 'date_value_04', 'date',          'NULL',                   nil],
      ['date_value_05', 'date_value_05', 'date',          'NULL',                   nil],
      ['project',       'project',       'nvarchar(100)', 'NULL',                   nil],
      ['jobid',         'jobid',         'nvarchar(100)', 'NULL',                   nil],
    ],
    database_connections: [
      {
        host: "10.135.204.161",
        database: "GSAStores",
        schema: "dbo",
        table: "Universal_Data_Import",
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
