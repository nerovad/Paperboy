# frozen_string_literal: true

[
  'Tasks',
  {
    steps: {
      enabled: true,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'chart_of_accounts'
    },
    source: {
      url: 'http://acweb/cutoff/WP Task on AUD Web Page.xlsx',
      location: 'tasks.xlsx',
      local: 'tasks.xlsx',
      format: :xlsx,
      strategy: :http
    },
    to_csv: {
      sheet: 0,
      header_row: 6,
      data_row: 7
    },
    header: [

      [ 'department', 'agency_id',  'nvarchar(3)',   'NOT NULL', nil ],
      [ 'task_code',  'task_id',    'nvarchar(max)', 'NOT NULL', nil ],
      [ 'long_name',  'long_name',  'nvarchar(max)', 'NOT NULL', nil ],
      [ 'short_name', 'short_name', 'nvarchar(max)', 'NOT NULL', nil ],
      [ 'active',     'active',     'bit',           'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'tasks',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
