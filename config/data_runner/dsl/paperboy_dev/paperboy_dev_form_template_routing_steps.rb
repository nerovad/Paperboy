# frozen_string_literal: true

[
  'Paperboy_dev_form_template_routing_steps',
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
    dependency: %w[Paperboy_dev_form_template_statuses Paperboy_dev_form_templates],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'form_template_routing_steps',
      local: 'paperboy_dev_form_template_routing_steps.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_id', 'form_template_id', 'bigint', 'NOT NULL', nil],
      ['step_number', 'step_number', 'int', 'NOT NULL', nil],
      ['routing_type', 'routing_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['form_template_status_id', 'form_template_status_id', 'bigint', 'NULL', nil],
      ['display_name', 'display_name', 'nvarchar(4000)', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['condition_operator', 'condition_operator', 'nvarchar(4000)', 'NULL', nil],
      ['condition_value', 'condition_value', 'nvarchar(4000)', 'NULL', nil],
      ['condition_field_name', 'condition_field_name', 'nvarchar(4000)', 'NULL', nil],
      ['org_filter_level', 'org_filter_level', 'nvarchar(4000)', 'NULL', nil],
      ['inbox_buttons', 'inbox_buttons', 'nvarchar(max)', 'NULL', nil],
      ['authorization_service_type', 'authorization_service_type', 'nvarchar(4000)', 'NULL', nil],
      ['approve_button_label', 'approve_button_label', 'nvarchar(4000)', 'NULL', nil],
      ['deny_button_label', 'deny_button_label', 'nvarchar(4000)', 'NULL', nil],
      ['complete_on_edit', 'complete_on_edit', 'bit', 'NOT NULL', nil],
      ['completion_rule', 'completion_rule', 'nvarchar(4000)', 'NOT NULL', nil],
      ['deny_rule', 'deny_rule', 'nvarchar(4000)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_template_routing_steps',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
