# frozen_string_literal: true

[
  'Printers',
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
      name: 'print_2_mail'
    },
    sop: {
      shared: :print_2_mail
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'printer_queues.xlsx'),
      local: 'printer_queues.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'printers.csv',
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['printer',  'printer',  'nvarchar(max)', 'NOT NULL', nil],
      ['ip',       'ip',       'nvarchar(max)', 'NOT NULL', nil],
      ['rip_type', 'rip_type', 'nvarchar(max)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'printers',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
