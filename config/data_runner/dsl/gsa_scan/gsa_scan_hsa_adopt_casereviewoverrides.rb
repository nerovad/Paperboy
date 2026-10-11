# frozen_string_literal: true

[
  'Gsa_scan_hsa_adopt_casereviewoverrides',
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
      table: 'HSA_Adopt_CaseReviewOverrides',
      local: 'gsa_scan_hsa_adopt_casereviewoverrides.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ChildCardID', 'ChildCardID', 'int', 'NOT NULL', nil],
      ['AdoptCardID', 'AdoptCardID', 'int', 'NULL', nil],
      ['BirthCardID', 'BirthCardID', 'int', 'NULL', nil],
      ['Decision', 'Decision', 'nvarchar(12)', 'NOT NULL', nil],
      ['ReviewedBy', 'ReviewedBy', 'nvarchar(200)', 'NOT NULL', nil],
      ['ReviewedDate', 'ReviewedDate', 'date', 'NOT NULL', nil],
      ['ReviewNote', 'ReviewNote', 'nvarchar(500)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HSA_Adopt_CaseReviewOverrides',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
