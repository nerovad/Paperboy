# frozen_string_literal: true

[
  'Paperboy_dev_form_collections',
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
      table: 'form_collections',
      local: 'paperboy_dev_form_collections.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['created_by_id', 'created_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_by_name', 'created_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_collections',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
