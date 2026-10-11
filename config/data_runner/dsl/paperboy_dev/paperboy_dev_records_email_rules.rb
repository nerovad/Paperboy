# frozen_string_literal: true

[
  'Paperboy_dev_records_email_rules',
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
      schema: 'dbo',
      table: 'records_email_rules',
      local: 'paperboy_dev_records_email_rules.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['table_slug', 'table_slug', 'nvarchar(100)', 'NOT NULL', nil],
      ['column_name', 'column_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['operator', 'operator', 'nvarchar(4000)', 'NOT NULL', nil],
      ['value', 'value', 'nvarchar(4000)', 'NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['message', 'message', 'nvarchar(max)', 'NOT NULL', nil],
      ['split_column', 'split_column', 'nvarchar(4000)', 'NULL', nil],
      ['recipients', 'recipients', 'nvarchar(max)', 'NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['frequency', 'frequency', 'nvarchar(4000)', 'NOT NULL', nil],
      ['time_of_day', 'time_of_day', 'nvarchar(4000)', 'NOT NULL', nil],
      ['day_of_week', 'day_of_week', 'int', 'NULL', nil],
      ['day_of_month', 'day_of_month', 'int', 'NULL', nil],
      ['enabled', 'enabled', 'bit', 'NOT NULL', nil],
      ['last_run_at', 'last_run_at', 'datetime2(6)', 'NULL', nil],
      ['next_run_at', 'next_run_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'records_email_rules',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
