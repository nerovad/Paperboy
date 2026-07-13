# frozen_string_literal: true

[
  'Usersettings',
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
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/usersettings.csv',
      local: 'usersettings.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id',                        'id',                        'bigint',         'IDENTITY(0,0) NOT NULL', nil],
      ['employee_id',               'employee_id',               'nvarchar(4000)', 'NOT NULL',               nil],
      ['inbox_email_notifications', 'inbox_email_notifications', 'bit',            'NOT NULL',               '((0))'],
      ['created_at',                'created_at',                'datetime2(6)',   'NOT NULL',               nil],
      ['updated_at',                'updated_at',                'datetime2(6)',   'NOT NULL',               nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'user_settings',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
