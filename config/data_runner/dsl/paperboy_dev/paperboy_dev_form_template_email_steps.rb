# frozen_string_literal: true

[
  'Paperboy_dev_form_template_email_steps',
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
    dependency: 'Paperboy_dev_form_templates',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'form_template_email_steps',
      local: 'paperboy_dev_form_template_email_steps.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_id', 'form_template_id', 'bigint', 'NOT NULL', nil],
      ['trigger_event', 'trigger_event', 'nvarchar(4000)', 'NOT NULL', nil],
      ['routing_step_number', 'routing_step_number', 'int', 'NULL', nil],
      ['recipient_type', 'recipient_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['custom_email', 'custom_email', 'nvarchar(4000)', 'NULL', nil],
      ['recipient_field_name', 'recipient_field_name', 'nvarchar(4000)', 'NULL', nil],
      ['attach_pdf', 'attach_pdf', 'bit', 'NOT NULL', nil],
      ['attach_media', 'attach_media', 'bit', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['authorization_service_type', 'authorization_service_type', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_template_email_steps',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
