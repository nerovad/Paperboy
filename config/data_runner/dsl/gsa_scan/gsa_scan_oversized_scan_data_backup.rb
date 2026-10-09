# frozen_string_literal: true

[
  'Gsa_scan_oversized_scan_data_backup',
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
      table: 'Oversized_Scan_Data_Backup',
      local: 'gsa_scan_oversized_scan_data_backup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Date', 'Date', 'date', 'NULL', nil],
      ['ProfileType', 'ProfileType', 'nvarchar(max)', 'NULL', nil],
      ['BU', 'BU', 'int', 'NULL', nil],
      ['Length', 'Length', 'float', 'NULL', nil],
      ['Width', 'Width', 'float', 'NULL', nil],
      ['Type', 'Type', 'nvarchar(max)', 'NULL', nil],
      ['FilePath', 'FilePath', 'nvarchar(max)', 'NULL', nil],
      ['FileName', 'FileName', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Oversized_Scan_Data_Backup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
