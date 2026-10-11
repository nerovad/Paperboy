# frozen_string_literal: true

[
  'Gsap2m_fudcount',
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
      table: 'FUDCount',
      local: 'gsap2m_fudcount.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['CntFUD9', 'CntFUD9', 'int', 'NULL', nil],
      ['FldUserDefined9', 'FldUserDefined9', 'nvarchar(100)', 'NULL', nil],
      ['OMSNumber', 'OMSNumber', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'FUDCount',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
