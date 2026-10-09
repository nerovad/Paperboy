# frozen_string_literal: true

[
  'Paperboy_dev_status_changes',
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
      table: 'status_changes',
      local: 'paperboy_dev_status_changes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['trackable_type', 'trackable_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['trackable_id', 'trackable_id', 'bigint', 'NOT NULL', nil],
      ['from_status', 'from_status', 'nvarchar(4000)', 'NULL', nil],
      ['to_status', 'to_status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['changed_by_id', 'changed_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['changed_by_name', 'changed_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['notes', 'notes', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'status_changes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
