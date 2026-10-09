# frozen_string_literal: true

[
  'Gsabss_datarunner_log',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'datarunner_log',
      local: 'gsabss_datarunner_log.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['run_id', 'run_id', 'uniqueidentifier', 'NOT NULL', nil],
      ['command', 'command', 'nvarchar(260)', 'NOT NULL', nil],
      ['script', 'script', 'nvarchar(260)', 'NOT NULL', nil],
      ['arguments', 'arguments', 'nvarchar(1000)', 'NULL', nil],
      ['selector', 'selector', 'nvarchar(255)', 'NULL', nil],
      ['status', 'status', 'varchar(20)', 'NOT NULL', nil],
      ['exit_status', 'exit_status', 'int', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NOT NULL', nil],
      ['completed_at', 'completed_at', 'datetime2(6)', 'NOT NULL', nil],
      ['duration_ms', 'duration_ms', 'int', 'NOT NULL', nil],
      ['logged_at', 'logged_at', 'datetime2(6)', 'NOT NULL', nil],
      ['cwd', 'cwd', 'nvarchar(4000)', 'NULL', nil],
      ['host_name', 'host_name', 'nvarchar(128)', 'NULL', nil],
      ['os_user', 'os_user', 'nvarchar(128)', 'NULL', nil],
      ['process_id', 'process_id', 'int', 'NULL', nil],
      ['git_sha', 'git_sha', 'char(40)', 'NULL', nil],
      ['error_class', 'error_class', 'nvarchar(200)', 'NULL', nil],
      ['error_message', 'error_message', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'datarunner_log',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
