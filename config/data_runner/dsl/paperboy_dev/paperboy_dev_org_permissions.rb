# frozen_string_literal: true

[
  'Paperboy_dev_org_permissions',
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
      table: 'org_permissions',
      local: 'paperboy_dev_org_permissions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(4000)', 'NULL', nil],
      ['division_id', 'division_id', 'nvarchar(4000)', 'NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(4000)', 'NULL', nil],
      ['permission_type', 'permission_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['permission_key', 'permission_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'org_permissions',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
