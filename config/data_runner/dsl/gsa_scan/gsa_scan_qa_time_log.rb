# frozen_string_literal: true

[
  'Gsa_scan_qa_time_log',
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
      name: 'gsa_scan'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'QA_Time_Log',
      local: 'gsa_scan_qa_time_log.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['SessionId', 'SessionId', 'uniqueidentifier', 'NOT NULL', nil],
      ['JobName', 'JobName', 'nvarchar(200)', 'NOT NULL', nil],
      ['BatchFile', 'BatchFile', 'nvarchar(400)', 'NOT NULL', nil],
      ['QAUser', 'QAUser', 'nvarchar(100)', 'NULL', nil],
      ['WindowsUser', 'WindowsUser', 'nvarchar(100)', 'NULL', nil],
      ['PCName', 'PCName', 'nvarchar(100)', 'NULL', nil],
      ['StartedAt', 'StartedAt', 'datetime2(0)', 'NOT NULL', nil],
      ['EndedAt', 'EndedAt', 'datetime2(0)', 'NOT NULL', nil],
      ['ActiveSeconds', 'ActiveSeconds', 'int', 'NOT NULL', nil],
      ['Outcome', 'Outcome', 'varchar(20)', 'NOT NULL', nil],
      ['DocsProduced', 'DocsProduced', 'int', 'NULL', nil],
      ['PagesIn', 'PagesIn', 'int', 'NULL', nil],
      ['PagesOut', 'PagesOut', 'int', 'NULL', nil],
      ['BudgetUnit', 'BudgetUnit', 'nvarchar(50)', 'NULL', nil],
      ['LoggedAt', 'LoggedAt', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'QA_Time_Log',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
