# frozen_string_literal: true

[
  'Paperboy_dev_form_templates',
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
      table: 'form_templates',
      local: 'paperboy_dev_form_templates.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['class_name', 'class_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['page_count', 'page_count', 'int', 'NOT NULL', nil],
      ['page_headers', 'page_headers', 'nvarchar(max)', 'NULL', nil],
      ['created_by', 'created_by', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['submission_type', 'submission_type', 'nvarchar(4000)', 'NULL', nil],
      ['approval_routing_to', 'approval_routing_to', 'nvarchar(4000)', 'NULL', nil],
      ['approval_employee_id', 'approval_employee_id', 'int', 'NULL', nil],
      ['has_dashboard', 'has_dashboard', 'bit', 'NULL', nil],
      ['inbox_buttons', 'inbox_buttons', 'nvarchar(max)', 'NULL', nil],
      ['status_transition_mode', 'status_transition_mode', 'nvarchar(4000)', 'NULL', nil],
      ['tags', 'tags', 'nvarchar(max)', 'NULL', nil],
      ['metabase_dashboard_id', 'metabase_dashboard_id', 'int', 'NULL', nil],
      ['archived', 'archived', 'bit', 'NOT NULL', nil],
      ['skip_code_generation', 'skip_code_generation', 'bit', 'NOT NULL', nil],
      ['reference_prefix', 'reference_prefix', 'nvarchar(4000)', 'NULL', nil],
      ['records_table', 'records_table', 'bit', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(500)', 'NULL', nil],
      ['form_number', 'form_number', 'nvarchar(30)', 'NULL', nil],
      ['form_type', 'form_type', 'nvarchar(50)', 'NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(10)', 'NULL', nil],
      ['division_id', 'division_id', 'nvarchar(20)', 'NULL', nil],
      ['department_id', 'department_id', 'nvarchar(20)', 'NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(20)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_templates',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
