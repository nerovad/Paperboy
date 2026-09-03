# frozen_string_literal: true

[
  'PrinterQueues',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/printer_queues.xlsx',
      local: 'printer_queues.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'printer_queues.csv',
    to_csv: {
      sheet: 1,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['printer',  'printer',  'nvarchar(max)', 'NOT NULL', nil],
      ['queue',    'queue',    'nvarchar(max)', 'NOT NULL', nil],
      ['location', 'location', 'nvarchar(max)', 'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'printer_queues',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
