# frozen_string_literal: true

[
  'Oms',
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
      name: 'print_2_mail_billing_data'
    },
    source: {
      location: 'oms.csv',
      local: 'oms.csv',
      format: :csv,
      strategy: :script,
      script: {
        path: 'script/ruby/data_runner/download/oms.rb',
        args: ['/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/OMS'],
        verify_target: false
      }
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'oms',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
