# frozen_string_literal: true

[
  'Paperboy_dev_scheduled_record_exports',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'scheduled_record_exports',
      local: 'paperboy_dev_scheduled_record_exports.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['table_slug', 'table_slug', 'nvarchar(100)', 'NOT NULL', nil],
      ['view_params', 'view_params', 'nvarchar(max)', 'NULL', nil],
      ['layout', 'layout', 'nvarchar(max)', 'NULL', nil],
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
        table: 'scheduled_record_exports',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
