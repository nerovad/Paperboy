# frozen_string_literal: true

[
  'Gsap2m_procedurelog',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'ProcedureLog',
      local: 'gsap2m_procedurelog.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['LogDate', 'LogDate', 'smalldatetime', 'NOT NULL', nil],
      ['DatabaseID', 'DatabaseID', 'int', 'NULL', nil],
      ['ObjectID', 'ObjectID', 'int', 'NULL', nil],
      ['ProcedureName', 'ProcedureName', 'nvarchar(400)', 'NULL', nil],
      ['ErrorLine', 'ErrorLine', 'int', 'NULL', nil],
      ['ErrorMessage', 'ErrorMessage', 'nvarchar(max)', 'NULL', nil],
      ['AdditionalInfo', 'AdditionalInfo', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'ProcedureLog',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
