# frozen_string_literal: true

[
  'Paperboy_dev_dam_recent_views',
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
      table: 'dam_recent_views',
      local: 'paperboy_dev_dam_recent_views.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['viewable_type', 'viewable_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['viewable_id', 'viewable_id', 'bigint', 'NOT NULL', nil],
      ['viewed_at', 'viewed_at', 'datetime2(6)', 'NOT NULL', nil],
      ['view_count', 'view_count', 'int', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_recent_views',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
