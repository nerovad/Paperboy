# frozen_string_literal: true

[
  'Gsabss_employees',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'employees',
      local: 'gsabss_employees.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'int', 'NOT NULL', nil],
      ['last_name', 'last_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['first_name', 'first_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['job_title', 'job_title', 'nvarchar(50)', 'NULL', nil],
      ['work_phone', 'work_phone', 'nvarchar(20)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(5)', 'NULL', nil],
      ['job_code', 'job_code', 'nvarchar(5)', 'NULL', nil],
      ['position', 'position', 'nvarchar(8)', 'NULL', nil],
      ['pay_status', 'pay_status', 'nvarchar(1)', 'NULL', nil],
      ['job_class', 'job_class', 'nvarchar(2)', 'NULL', nil],
      ['department', 'department', 'nvarchar(50)', 'NULL', nil],
      ['type', 'type', 'nvarchar(1)', 'NULL', nil],
      ['supervisor_id', 'supervisor_id', 'int', 'NULL', nil],
      ['supervisor_last_name', 'supervisor_last_name', 'nvarchar(50)', 'NULL', nil],
      ['supervisor_first_name', 'supervisor_first_name', 'nvarchar(50)', 'NULL', nil],
      ['person_email', 'person_email', 'nvarchar(50)', 'NULL', nil],
      ['email', 'email', 'nvarchar(50)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'employees',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
