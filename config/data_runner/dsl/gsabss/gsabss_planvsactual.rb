# frozen_string_literal: true

[
  'Gsabss_planvsactual',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'PlanVsActual',
      local: 'gsabss_planvsactual.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['YEAR', 'YEAR', 'varchar(4)', 'NOT NULL', nil],
      ['PLAN', 'PLAN', 'varchar(1)', 'NOT NULL', nil],
      ['TYPE', 'TYPE', 'varchar(3)', 'NOT NULL', nil],
      ['SERVICE', 'SERVICE', 'varchar(15)', 'NOT NULL', nil],
      ['SERVICETYPE', 'SERVICETYPE', 'varchar(15)', 'NOT NULL', nil],
      ['Jul', 'Jul', 'float', 'NOT NULL', nil],
      ['Aug', 'Aug', 'float', 'NOT NULL', nil],
      ['Sep', 'Sep', 'float', 'NOT NULL', nil],
      ['Oct', 'Oct', 'float', 'NOT NULL', nil],
      ['Nov', 'Nov', 'float', 'NOT NULL', nil],
      ['Dec', 'Dec', 'float', 'NOT NULL', nil],
      ['Jan', 'Jan', 'float', 'NOT NULL', nil],
      ['Feb', 'Feb', 'float', 'NOT NULL', nil],
      ['Mar', 'Mar', 'float', 'NOT NULL', nil],
      ['Apr', 'Apr', 'float', 'NOT NULL', nil],
      ['May', 'May', 'float', 'NOT NULL', nil],
      ['Jun', 'Jun', 'float', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'PlanVsActual',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
