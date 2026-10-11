# frozen_string_literal: true

[
  'Gsa_scan_digitization_log',
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
      table: 'Digitization_Log',
      local: 'gsa_scan_digitization_log.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Budget_Unit', 'Budget_Unit', 'nchar(10)', 'NULL', nil],
      ['BatchCreateDate', 'BatchCreateDate', 'date', 'NULL', nil],
      ['BatchID', 'BatchID', 'nvarchar(max)', 'NULL', nil],
      ['DocumentPageCount', 'DocumentPageCount', 'int', 'NULL', nil],
      ['Box_Number_Name', 'Box_Number_Name', 'nvarchar(max)', 'NULL', nil],
      ['File_Number_Name', 'File_Number_Name', 'nvarchar(max)', 'NULL', nil],
      ['CaptureProfileName', 'CaptureProfileName', 'nvarchar(max)', 'NULL', nil],
      ['Timestamp', 'Timestamp', 'nvarchar(max)', 'NULL', nil],
      ['Document Name', 'Document Name', 'varchar(7500)', 'NULL', nil],
      ['Date', 'Date', 'varchar(255)', 'NULL', nil],
      ['Additional_Data', 'Additional_Data', 'nvarchar(max)', 'NULL', nil],
      ['Document_Type', 'Document_Type', 'nvarchar(max)', 'NULL', nil],
      ['Folder_name', 'Folder_name', 'varchar(255)', 'NULL', nil],
      ['Document_Path', 'Document_Path', 'varchar(255)', 'NULL', nil],
      ['OCR_Path', 'OCR_Path', 'varchar(255)', 'NULL', nil],
      ['Channel', 'Channel', 'varchar(255)', 'NULL', nil],
      ['BSDOC Folder Output Name', 'BSDOC Folder Output Name', 'varchar(255)', 'NULL', nil],
      ['ACCELA Folder Output Name', 'ACCELA Folder Output Name', 'varchar(255)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Digitization_Log',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
