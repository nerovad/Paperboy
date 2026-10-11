# frozen_string_literal: true

[
  'Gsa_scan_job',
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
      table: 'Job',
      local: 'gsa_scan_job.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['JobID', 'JobID', 'varchar(50)', 'NOT NULL', nil],
      ['IsActive', 'IsActive', 'bit', 'NOT NULL', nil],
      ['JobType', 'JobType', 'varchar(30)', 'NULL', nil],
      ['BudgetUnit', 'BudgetUnit', 'varchar(20)', 'NULL', nil],
      ['Agency', 'Agency', 'varchar(50)', 'NULL', nil],
      ['Department', 'Department', 'varchar(100)', 'NULL', nil],
      ['JobName', 'JobName', 'varchar(100)', 'NOT NULL', nil],
      ['JobDescription', 'JobDescription', 'varchar(500)', 'NULL', nil],
      ['CreatedAtUtc', 'CreatedAtUtc', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Job',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
