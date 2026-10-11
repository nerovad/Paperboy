# frozen_string_literal: true

[
  'Gsabss_p2m_oms_upload_files',
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
    dependency: 'Gsabss_p2m_oms_uploads',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'p2m_oms_upload_files',
      local: 'gsabss_p2m_oms_upload_files.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['oms_upload_id', 'oms_upload_id', 'bigint', 'NOT NULL', nil],
      ['original_filename', 'original_filename', 'nvarchar(4000)', 'NOT NULL', nil],
      ['category', 'category', 'nvarchar(4000)', 'NOT NULL', nil],
      ['byte_size', 'byte_size', 'bigint', 'NOT NULL', nil],
      ['checksum_algorithm', 'checksum_algorithm', 'nvarchar(4000)', 'NOT NULL', nil],
      ['checksum', 'checksum', 'nvarchar(64)', 'NOT NULL', nil],
      ['source_modified_at', 'source_modified_at', 'datetime2(6)', 'NULL', nil],
      ['archived_path', 'archived_path', 'nvarchar(4000)', 'NULL', nil],
      ['archived_at', 'archived_at', 'datetime2(6)', 'NULL', nil],
      ['retention_class', 'retention_class', 'nvarchar(4000)', 'NULL', nil],
      ['retention_starts_on', 'retention_starts_on', 'date', 'NULL', nil],
      ['retain_until', 'retain_until', 'date', 'NULL', nil],
      ['disposition_status', 'disposition_status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['disposed_at', 'disposed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'p2m_oms_upload_files',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
