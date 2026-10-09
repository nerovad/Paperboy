# frozen_string_literal: true

[
  'Gsabss_billing_email_subjects',
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
      table: 'Billing_Email_Subjects',
      local: 'gsabss_billing_email_subjects.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['billing_type', 'billing_type', 'varchar(3)', 'NOT NULL', nil],
      ['subject_format', 'subject_format', 'varchar(500)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'Billing_Email_Subjects',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
