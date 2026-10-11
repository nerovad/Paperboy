# frozen_string_literal: true

[
  'Paperboy_dev_submission_step_tasks',
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
      table: 'submission_step_tasks',
      local: 'paperboy_dev_submission_step_tasks.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['submission_type', 'submission_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['submission_id', 'submission_id', 'bigint', 'NOT NULL', nil],
      ['step_number', 'step_number', 'int', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['routing_type', 'routing_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['org_filter_level', 'org_filter_level', 'nvarchar(4000)', 'NULL', nil],
      ['authorization_service_type', 'authorization_service_type', 'nvarchar(4000)', 'NULL', nil],
      ['assignee_id', 'assignee_id', 'nvarchar(4000)', 'NULL', nil],
      ['state', 'state', 'nvarchar(4000)', 'NOT NULL', nil],
      ['acted_by_id', 'acted_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['acted_by_name', 'acted_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['acted_at', 'acted_at', 'datetime2(6)', 'NULL', nil],
      ['notes', 'notes', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'submission_step_tasks',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
