# frozen_string_literal: true

[
  'Gsa_scan_scan_summary',
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
      table: 'Scan_Summary',
      local: 'gsa_scan_scan_summary.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['FYEAR', 'FYEAR', 'nvarchar(4)', 'NULL', nil],
      ['APMON', 'APMON', 'nvarchar(4)', 'NULL', nil],
      ['TEAM', 'TEAM', 'nvarchar(8)', 'NULL', nil],
      ['TYPE', 'TYPE', 'nvarchar(3)', 'NULL', nil],
      ['CUNIT', 'CUNIT', 'nvarchar(4)', 'NULL', nil],
      ['QUANTITY', 'QUANTITY', 'int', 'NULL', nil],
      ['DATE', 'DATE', 'date', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Scan_Summary',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
