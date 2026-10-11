# frozen_string_literal: true

[
  'Gsa_scan_jobalias',
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
    dependency: 'Gsa_scan_job',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'JobAlias',
      local: 'gsa_scan_jobalias.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['JobID', 'JobID', 'varchar(50)', 'NOT NULL', nil],
      ['Alias', 'Alias', 'varchar(100)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'JobAlias',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
