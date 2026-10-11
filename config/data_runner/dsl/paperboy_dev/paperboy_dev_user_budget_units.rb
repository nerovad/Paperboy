# frozen_string_literal: true

[
  'Paperboy_dev_user_budget_units',
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
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'aim',
      table: 'user_budget_units',
      local: 'paperboy_dev_user_budget_units.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NOT NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(10)', 'NOT NULL', nil],
      ['bu_admin', 'bu_admin', 'bit', 'NOT NULL', nil],
      ['granted_by', 'granted_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['hidden', 'hidden', 'bit', 'NOT NULL', nil],
      ['shared_queue', 'shared_queue', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'user_budget_units',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
