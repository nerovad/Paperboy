# frozen_string_literal: true

[
  'Gsa_scan_hca_bh_qa_time_tracking',
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
      table: 'HCA_BH_QA_Time_Tracking',
      local: 'gsa_scan_hca_bh_qa_time_tracking.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['PDF_Name', 'PDF_Name', 'nvarchar(255)', 'NOT NULL', nil],
      ['QCMinutes', 'QCMinutes', 'decimal(6,2)', 'NOT NULL', nil],
      ['CommittedBy', 'CommittedBy', 'nvarchar(100)', 'NOT NULL', nil],
      ['Timestamp', 'Timestamp', 'datetime', 'NOT NULL', nil],
      ['BoxNumber', 'BoxNumber', 'nvarchar(100)', 'NULL', nil],
      ['PageCount', 'PageCount', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HCA_BH_QA_Time_Tracking',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
