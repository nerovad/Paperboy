# frozen_string_literal: true

[
  'Gsa_scan_projectmap',
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
      table: 'ProjectMap',
      local: 'gsa_scan_projectmap.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['FolderName', 'FolderName', 'nvarchar(100)', 'NOT NULL', nil],
      ['ProjectName', 'ProjectName', 'nvarchar(100)', 'NOT NULL', nil],
      ['BU', 'BU', 'varchar(20)', 'NULL', nil],
      ['IsActive', 'IsActive', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'ProjectMap',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
