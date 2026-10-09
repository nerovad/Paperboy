# frozen_string_literal: true

[
  'Gsa_scan_aim_processing_logs',
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
      table: 'Aim_Processing_Logs',
      local: 'gsa_scan_aim_processing_logs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['FileName', 'FileName', 'nvarchar(max)', 'NULL', nil],
      ['Submitter', 'Submitter', 'nvarchar(max)', 'NULL', nil],
      ['BU', 'BU', 'nvarchar(max)', 'NULL', nil],
      ['VendorName', 'VendorName', 'nvarchar(max)', 'NULL', nil],
      ['InvoiceNumber', 'InvoiceNumber', 'nvarchar(max)', 'NULL', nil],
      ['InvoiceTotal', 'InvoiceTotal', 'nvarchar(max)', 'NULL', nil],
      ['InvoiceDate', 'InvoiceDate', 'date', 'NULL', nil],
      ['ExtractedMetadata', 'ExtractedMetadata', 'nvarchar(max)', 'NULL', nil],
      ['Status', 'Status', 'nvarchar(50)', 'NULL', nil],
      ['ErrorMessage', 'ErrorMessage', 'nvarchar(max)', 'NULL', nil],
      ['ProcessedTimestamp', 'ProcessedTimestamp', 'datetime', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Aim_Processing_Logs',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
