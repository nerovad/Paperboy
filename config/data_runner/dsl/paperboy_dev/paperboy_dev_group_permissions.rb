# frozen_string_literal: true

[
  'Paperboy_dev_group_permissions',
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
      table: 'Group_Permissions',
      local: 'paperboy_dev_group_permissions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['GroupID', 'GroupID', 'int', 'NOT NULL', nil],
      ['Permission_Type', 'Permission_Type', 'nvarchar(50)', 'NOT NULL', nil],
      ['Permission_Key', 'Permission_Key', 'nvarchar(255)', 'NOT NULL', nil],
      ['Created_At', 'Created_At', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'Group_Permissions',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
