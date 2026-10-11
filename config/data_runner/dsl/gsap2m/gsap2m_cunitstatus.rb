# frozen_string_literal: true

[
  'Gsap2m_cunitstatus',
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
      table: 'CUnitStatus',
      local: 'gsap2m_cunitstatus.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['CUnitID', 'CUnitID', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['CUnit', 'CUnit', 'int', 'NOT NULL', nil],
      ['WhenCharged', 'WhenCharged', 'datetime', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'CUnitStatus',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
