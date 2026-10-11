# frozen_string_literal: true

[
  'Gsabss_p2m_oms_uploads',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'p2m_oms_uploads',
      local: 'gsabss_p2m_oms_uploads.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['oms_number', 'oms_number', 'nvarchar(9)', 'NOT NULL', nil],
      ['mailer_date', 'mailer_date', 'date', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['validation_status', 'validation_status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['import_status', 'import_status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['archive_status', 'archive_status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['budget_job_id', 'budget_job_id', 'nvarchar(4000)', 'NULL', nil],
      ['aims_job_id', 'aims_job_id', 'nvarchar(4000)', 'NULL', nil],
      ['document_profile', 'document_profile', 'nvarchar(4000)', 'NULL', nil],
      ['production_workflow', 'production_workflow', 'nvarchar(4000)', 'NULL', nil],
      ['staged_by', 'staged_by', 'nvarchar(4000)', 'NULL', nil],
      ['removed_by', 'removed_by', 'nvarchar(4000)', 'NULL', nil],
      ['companion_file_count', 'companion_file_count', 'int', 'NOT NULL', nil],
      ['postal_report_count', 'postal_report_count', 'int', 'NOT NULL', nil],
      ['input_record_count', 'input_record_count', 'int', 'NULL', nil],
      ['mailed_record_count', 'mailed_record_count', 'int', 'NULL', nil],
      ['non_mailed_record_count', 'non_mailed_record_count', 'int', 'NULL', nil],
      ['removal_reason', 'removal_reason', 'nvarchar(max)', 'NULL', nil],
      ['failure_message', 'failure_message', 'nvarchar(max)', 'NULL', nil],
      ['staged_at', 'staged_at', 'datetime2(6)', 'NULL', nil],
      ['last_seen_at', 'last_seen_at', 'datetime2(6)', 'NULL', nil],
      ['validation_started_at', 'validation_started_at', 'datetime2(6)', 'NULL', nil],
      ['validated_at', 'validated_at', 'datetime2(6)', 'NULL', nil],
      ['import_started_at', 'import_started_at', 'datetime2(6)', 'NULL', nil],
      ['imported_at', 'imported_at', 'datetime2(6)', 'NULL', nil],
      ['archived_at', 'archived_at', 'datetime2(6)', 'NULL', nil],
      ['failed_at', 'failed_at', 'datetime2(6)', 'NULL', nil],
      ['removed_at', 'removed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'p2m_oms_uploads',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
