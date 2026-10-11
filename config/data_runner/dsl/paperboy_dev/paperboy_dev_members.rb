# frozen_string_literal: true

[
  'Paperboy_dev_members',
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
      schema: 'aim',
      table: 'members',
      local: 'paperboy_dev_members.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NOT NULL', nil],
      ['added_by', 'added_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['fusion_team', 'fusion_team', 'nvarchar(100)', 'NULL', nil],
      ['fusion_roles', 'fusion_roles', 'nvarchar(255)', 'NULL', nil],
      ['deactivated_at', 'deactivated_at', 'datetime2(6)', 'NULL', nil],
      ['deactivated_by', 'deactivated_by', 'nvarchar(255)', 'NULL', nil],
      ['deactivation_reason', 'deactivation_reason', 'nvarchar(500)', 'NULL', nil],
      ['fiscal', 'fiscal', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'members',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
