# frozen_string_literal: true

[
  'Calsaws_exportimage',
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
      name: 'calsaws'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Calsaws',
      schema: 'dbo',
      table: 'ExportImage',
      local: 'calsaws_exportimage.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['ExportDocumentId', 'ExportDocumentId', 'int', 'NULL', nil],
      ['Status', 'Status', 'int', 'NULL', nil],
      ['ErrorType', 'ErrorType', 'varchar(255)', 'NULL', nil],
      ['ErrorMessage', 'ErrorMessage', 'varchar(3000)', 'NULL', nil],
      ['ProcessingThreadName', 'ProcessingThreadName', 'varchar(255)', 'NULL', nil],
      ['DateCreated', 'DateCreated', 'datetime', 'NOT NULL', nil],
      ['DateModified', 'DateModified', 'datetime', 'NOT NULL', nil],
      ['DateCompleted', 'DateCompleted', 'datetime', 'NULL', nil],
      ['ScanSequenceId', 'ScanSequenceId', 'int', 'NULL', nil],
      ['Fullpath', 'Fullpath', 'varchar(255)', 'NULL', nil],
      ['Filename', 'Filename', 'varchar(255)', 'NULL', nil],
      ['Filesize', 'Filesize', 'int', 'NULL', nil],
      ['IsSeperator', 'IsSeperator', 'bit', 'NULL', nil],
      ['DocumentId', 'DocumentId', 'varchar(255)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'calsaws',
        table: 'ExportImage',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
