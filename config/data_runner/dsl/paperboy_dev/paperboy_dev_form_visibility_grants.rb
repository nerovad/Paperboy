# frozen_string_literal: true

[
  'Paperboy_dev_form_visibility_grants',
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
      table: 'form_visibility_grants',
      local: 'paperboy_dev_form_visibility_grants.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_type', 'form_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['grantee_type', 'grantee_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['applies_to', 'applies_to', 'nvarchar(4000)', 'NOT NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(4000)', 'NULL', nil],
      ['division_id', 'division_id', 'nvarchar(4000)', 'NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_visibility_grants',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
