# frozen_string_literal: true

[
  'Paperboy_dev_bike_lockers',
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
      table: 'bike_lockers',
      local: 'paperboy_dev_bike_lockers.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['lot_id', 'lot_id', 'bigint', 'NOT NULL', nil],
      ['locker_number', 'locker_number', 'int', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['assigned_employee_id', 'assigned_employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['assigned_at', 'assigned_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'bike_lockers',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
