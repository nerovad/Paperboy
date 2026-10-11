# frozen_string_literal: true

[
  'Gsap2m_db_errors',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'DB_Errors',
      local: 'gsap2m_db_errors.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ErrorID', 'ErrorID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['UserName', 'UserName', 'varchar(100)', 'NULL', nil],
      ['ErrorNumber', 'ErrorNumber', 'int', 'NULL', nil],
      ['ErrorState', 'ErrorState', 'int', 'NULL', nil],
      ['ErrorSeverity', 'ErrorSeverity', 'int', 'NULL', nil],
      ['ErrorLine', 'ErrorLine', 'int', 'NULL', nil],
      ['ErrorProcedure', 'ErrorProcedure', 'varchar(max)', 'NULL', nil],
      ['ErrorMessage', 'ErrorMessage', 'varchar(max)', 'NULL', nil],
      ['ErrorDateTime', 'ErrorDateTime', 'datetime', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'DB_Errors',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
