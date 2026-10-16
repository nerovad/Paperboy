# frozen_string_literal: true

[
  'Paperboy_dev_alert_settings',
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
      schema: 'aim',
      table: 'alert_settings',
      local: 'paperboy_dev_alert_settings.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['agency_group_id', 'agency_group_id', 'bigint', 'NOT NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(10)', 'NULL', nil],
      ['kind', 'kind', 'nvarchar(40)', 'NOT NULL', nil],
      ['enabled', 'enabled', 'bit', 'NOT NULL', nil],
      ['days', 'days', 'int', 'NULL', nil],
      ['updated_by', 'updated_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'alert_settings',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
