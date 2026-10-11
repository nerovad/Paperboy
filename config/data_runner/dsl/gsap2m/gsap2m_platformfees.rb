# frozen_string_literal: true

[
  'Gsap2m_platformfees',
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
      table: 'PlatformFees',
      local: 'gsap2m_platformfees.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['CUnit', 'CUnit', 'int', 'NOT NULL', nil],
      ['Tier1Fee', 'Tier1Fee', 'decimal(9,3)', 'NOT NULL', nil],
      ['Tier2Fee', 'Tier2Fee', 'decimal(9,3)', 'NOT NULL', nil],
      ['Tier3Fee', 'Tier3Fee', 'decimal(9,3)', 'NOT NULL', nil],
      ['ImportDateTime', 'ImportDateTime', 'datetime', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'PlatformFees',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
