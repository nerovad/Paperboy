# frozen_string_literal: true

[
  'Paperboy_dev_form_template_statuses',
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
      table: 'form_template_statuses',
      local: 'paperboy_dev_form_template_statuses.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_id', 'form_template_id', 'bigint', 'NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['category', 'category', 'nvarchar(4000)', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NULL', nil],
      ['is_initial', 'is_initial', 'bit', 'NULL', nil],
      ['is_end', 'is_end', 'bit', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['auto_generated', 'auto_generated', 'bit', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_template_statuses',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
