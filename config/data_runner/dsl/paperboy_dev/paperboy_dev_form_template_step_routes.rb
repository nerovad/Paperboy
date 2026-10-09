# frozen_string_literal: true

[
  'Paperboy_dev_form_template_step_routes',
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
      table: 'form_template_step_routes',
      local: 'paperboy_dev_form_template_step_routes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_routing_step_id', 'form_template_routing_step_id', 'bigint', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['routing_type', 'routing_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['org_filter_level', 'org_filter_level', 'nvarchar(4000)', 'NULL', nil],
      ['authorization_service_type', 'authorization_service_type', 'nvarchar(4000)', 'NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_template_step_routes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
