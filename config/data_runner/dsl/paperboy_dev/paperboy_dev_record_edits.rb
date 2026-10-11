# frozen_string_literal: true

[
  'Paperboy_dev_record_edits',
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
      table: 'record_edits',
      local: 'paperboy_dev_record_edits.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['record_type', 'record_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['record_id', 'record_id', 'bigint', 'NOT NULL', nil],
      ['table_slug', 'table_slug', 'nvarchar(4000)', 'NOT NULL', nil],
      ['column_name', 'column_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['old_value', 'old_value', 'nvarchar(max)', 'NULL', nil],
      ['new_value', 'new_value', 'nvarchar(max)', 'NULL', nil],
      ['changed_by_id', 'changed_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['changed_by_name', 'changed_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['action', 'action', 'nvarchar(10)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'record_edits',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
