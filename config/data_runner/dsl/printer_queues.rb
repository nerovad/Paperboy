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
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/printer_queues.xlsx',
      local: 'printer_queues.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['printer',  'printer',  'nvarchar(max)', 'NULL', nil],
      ['ip',       'ip',       'nvarchar(max)', 'NULL', nil],
      ['rip_type', 'rip_type', 'nvarchar(max)', 'NULL', nil],
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
