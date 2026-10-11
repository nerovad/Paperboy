# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_processes',
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
      table: 'solid_queue_processes',
      local: 'paperboy_dev_solid_queue_processes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['kind', 'kind', 'nvarchar(4000)', 'NOT NULL', nil],
      ['last_heartbeat_at', 'last_heartbeat_at', 'datetime2(6)', 'NOT NULL', nil],
      ['supervisor_id', 'supervisor_id', 'bigint', 'NULL', nil],
      ['pid', 'pid', 'int', 'NOT NULL', nil],
      ['hostname', 'hostname', 'nvarchar(4000)', 'NULL', nil],
      ['metadata', 'metadata', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_processes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
