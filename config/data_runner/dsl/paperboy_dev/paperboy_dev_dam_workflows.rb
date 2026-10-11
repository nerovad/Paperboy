# frozen_string_literal: true

[
  'Paperboy_dev_dam_workflows',
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
      table: 'dam_workflows',
      local: 'paperboy_dev_dam_workflows.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['slug', 'slug', 'nvarchar(4000)', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['runtime', 'runtime', 'nvarchar(4000)', 'NOT NULL', nil],
      ['entrypoint', 'entrypoint', 'nvarchar(4000)', 'NULL', nil],
      ['default_arguments', 'default_arguments', 'nvarchar(max)', 'NULL', nil],
      ['trigger', 'trigger', 'nvarchar(4000)', 'NOT NULL', nil],
      ['schedule', 'schedule', 'nvarchar(4000)', 'NULL', nil],
      ['applies_to_media_types', 'applies_to_media_types', 'nvarchar(4000)', 'NULL', nil],
      ['enabled', 'enabled', 'bit', 'NOT NULL', nil],
      ['created_by_id', 'created_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_by_name', 'created_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['last_run_at', 'last_run_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_workflows',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
