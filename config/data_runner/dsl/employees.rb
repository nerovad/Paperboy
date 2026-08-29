# frozen_string_literal: true

[
  "Employees",
  {
    steps: {
      manual: { enabled: true, steps: Workflow::MANUAL_STEPS },
      scheduled: { enabled: true, frequency: :daily, steps: Workflow::SCHEDULED_STEPS }
    },
    group: {
      name: 'human_resources'
    },
    source: {
      host: "GSASQL16",
      database: "GSABSS",
      schema: "dbo",
      table: "employees",
      local: "employees.csv",
      format: :csv,
      strategy: :replicate
    },

    header: [

      ['id',                    'id',                    'int',          'NOT NULL', nil],
      ['last_name',             'last_name',             'nvarchar(50)', 'NOT NULL', nil],
      ['first_name',            'first_name',            'nvarchar(50)', 'NOT NULL', nil],
      ['job_title',             'job_title',             'nvarchar(50)', 'NULL',     nil],
      ['work_phone',            'work_phone',            'nvarchar(20)', 'NULL',     nil],
      ['agency',                nil,                     'nvarchar(4)',  'NULL',     nil],
      ['unit',                  'unit',                  'nvarchar(5)',  'NULL',     nil],
      ['job_code',              'job_code',              'nvarchar(5)',  'NULL',     nil],
      ['position',              'position',              'nvarchar(8)',  'NULL',     nil],
      ['pay_status',            'pay_status',            'nvarchar(1)',  'NULL',     nil],
      ['job_class',             'job_class',             'nvarchar(2)',  'NULL',     nil],
      ['department',            nil,                     'nvarchar(50)', 'NULL',     nil],
      ['type',                  'type',                  'nvarchar(1)',  'NULL',     nil],
      ['supervisor_id',         'supervisor_id',         'int',          'NULL',     nil],
      ['supervisor_last_name',  'supervisor_last_name',  'nvarchar(50)', 'NULL',     nil],
      ['supervisor_first_name', 'supervisor_first_name', 'nvarchar(50)', 'NULL',     nil],
      ['person_email',          nil,                     'nvarchar(50)', 'NULL',     nil],
      ['email',                 'email',                 'nvarchar(50)', 'NULL',     nil],
      [nil,                     'active',                'bit',          'NOT NULL', 1],
    ],
    database_connections: [
      {
        host: "GSASQL16",
        database: "GSARecords",
        schema: "dbo",
        table: "employees",
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
