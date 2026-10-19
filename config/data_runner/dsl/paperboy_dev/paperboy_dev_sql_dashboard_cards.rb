# frozen_string_literal: true

[
  'Paperboy_dev_sql_dashboard_cards',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'sql_dashboard_cards',
      local: 'paperboy_dev_sql_dashboard_cards.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['sql_dashboard_id', 'sql_dashboard_id', 'bigint', 'NOT NULL', nil],
      ['sql_dashboard_query_id', 'sql_dashboard_query_id', 'bigint', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['width', 'width', 'nvarchar(4000)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'sql_dashboard_cards',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
