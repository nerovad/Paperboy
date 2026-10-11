# frozen_string_literal: true

[
  'Paperboy_dev_form_template_copy_recipients',
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
    dependency: 'Paperboy_dev_form_templates',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'form_template_copy_recipients',
      local: 'paperboy_dev_form_template_copy_recipients.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_id', 'form_template_id', 'bigint', 'NOT NULL', nil],
      ['recipient_type', 'recipient_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['trigger_event', 'trigger_event', 'nvarchar(4000)', 'NOT NULL', nil],
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
        table: 'form_template_copy_recipients',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
