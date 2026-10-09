# frozen_string_literal: true

[
  'Paperboy_dev_dam_access_rules',
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
      table: 'dam_access_rules',
      local: 'paperboy_dev_dam_access_rules.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(4000)', 'NULL', nil],
      ['division_id', 'division_id', 'nvarchar(4000)', 'NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(4000)', 'NULL', nil],
      ['conditions', 'conditions', 'nvarchar(max)', 'NULL', nil],
      ['can_download', 'can_download', 'bit', 'NOT NULL', nil],
      ['can_share', 'can_share', 'bit', 'NOT NULL', nil],
      ['can_publish', 'can_publish', 'bit', 'NOT NULL', nil],
      ['can_edit', 'can_edit', 'bit', 'NOT NULL', nil],
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
        table: 'dam_access_rules',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
