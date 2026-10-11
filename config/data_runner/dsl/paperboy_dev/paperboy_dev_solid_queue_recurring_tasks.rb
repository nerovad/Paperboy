# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_recurring_tasks',
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
      table: 'solid_queue_recurring_tasks',
      local: 'paperboy_dev_solid_queue_recurring_tasks.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['schedule', 'schedule', 'nvarchar(4000)', 'NOT NULL', nil],
      ['command', 'command', 'nvarchar(2048)', 'NULL', nil],
      ['class_name', 'class_name', 'nvarchar(4000)', 'NULL', nil],
      ['arguments', 'arguments', 'nvarchar(max)', 'NULL', nil],
      ['queue_name', 'queue_name', 'nvarchar(4000)', 'NULL', nil],
      ['priority', 'priority', 'int', 'NULL', nil],
      ['static', 'static', 'bit', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_recurring_tasks',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
