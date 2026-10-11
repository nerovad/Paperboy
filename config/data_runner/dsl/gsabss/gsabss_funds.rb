# frozen_string_literal: true

[
  'Gsabss_funds',
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
      table: 'funds',
      local: 'gsabss_funds.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['fund_id', 'fund_id', 'nvarchar(4)', 'NOT NULL', nil],
      ['long_name', 'long_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['short_name', 'short_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['fund_class', 'fund_class', 'nvarchar(50)', 'NOT NULL', nil],
      ['fund_category', 'fund_category', 'nvarchar(50)', 'NOT NULL', nil],
      ['fund_type', 'fund_type', 'nvarchar(50)', 'NOT NULL', nil],
      ['fund_group', 'fund_group', 'nvarchar(50)', 'NOT NULL', nil],
      ['cafr_type', 'cafr_type', 'nvarchar(50)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'funds',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
