# frozen_string_literal: true

[
  'Paperboy_dev_form_fields',
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
      table: 'form_fields',
      local: 'paperboy_dev_form_fields.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_template_id', 'form_template_id', 'bigint', 'NOT NULL', nil],
      ['field_name', 'field_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['field_type', 'field_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NULL', nil],
      ['page_number', 'page_number', 'int', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NULL', nil],
      ['options', 'options', 'nvarchar(max)', 'NULL', nil],
      ['required', 'required', 'bit', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['restricted_to_type', 'restricted_to_type', 'nvarchar(4000)', 'NULL', nil],
      ['restricted_to_employee_id', 'restricted_to_employee_id', 'int', 'NULL', nil],
      ['restricted_to_group_id', 'restricted_to_group_id', 'int', 'NULL', nil],
      ['conditional_field_id', 'conditional_field_id', 'int', 'NULL', nil],
      ['conditional_values', 'conditional_values', 'nvarchar(max)', 'NULL', nil],
      ['read_only', 'read_only', 'nvarchar(4000)', 'NULL', nil],
      ['conditional_answer_field_id', 'conditional_answer_field_id', 'int', 'NULL', nil],
      ['conditional_answer_mappings', 'conditional_answer_mappings', 'nvarchar(max)', 'NULL', nil],
      ['has_custom_view', 'has_custom_view', 'bit', 'NOT NULL', nil],
      ['visible_to_filler', 'visible_to_filler', 'bit', 'NOT NULL', nil],
      ['restricted_to_org_filter_level', 'restricted_to_org_filter_level', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_fields',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
