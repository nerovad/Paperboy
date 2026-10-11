# frozen_string_literal: true

[
  'Gsa_scan_boxstatuschoice',
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
      table: 'BoxStatusChoice',
      local: 'gsa_scan_boxstatuschoice.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['StatusID', 'StatusID', 'int', 'NOT NULL', nil],
      ['StatusName', 'StatusName', 'nvarchar(40)', 'NOT NULL', nil],
      ['SortOrder', 'SortOrder', 'int', 'NOT NULL', nil],
      ['IsActive', 'IsActive', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'BoxStatusChoice',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
