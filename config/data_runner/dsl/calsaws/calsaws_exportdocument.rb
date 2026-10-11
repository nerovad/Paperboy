# frozen_string_literal: true

[
  'Calsaws_exportdocument',
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
      table: 'ExportDocument',
      local: 'calsaws_exportdocument.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Status', 'Status', 'int', 'NULL', nil],
      ['ErrorType', 'ErrorType', 'varchar(255)', 'NULL', nil],
      ['ErrorMessage', 'ErrorMessage', 'varchar(3000)', 'NULL', nil],
      ['ProcessingThreadName', 'ProcessingThreadName', 'varchar(255)', 'NULL', nil],
      ['DateCreated', 'DateCreated', 'datetime', 'NOT NULL', nil],
      ['DateModified', 'DateModified', 'datetime', 'NOT NULL', nil],
      ['DateCompleted', 'DateCompleted', 'datetime', 'NULL', nil],
      ['IsItBarcoded', 'IsItBarcoded', 'bit', 'NULL', nil],
      ['BarcodeValue', 'BarcodeValue', 'varchar(255)', 'NULL', nil],
      ['BatchStartDateTime', 'BatchStartDateTime', 'datetime', 'NULL', nil],
      ['BatchProcessDate', 'BatchProcessDate', 'datetime', 'NULL', nil],
      ['JobName', 'JobName', 'varchar(255)', 'NULL', nil],
      ['OperatorName', 'OperatorName', 'varchar(255)', 'NULL', nil],
      ['FilePath', 'FilePath', 'varchar(255)', 'NULL', nil],
      ['ReturnMailIndicator', 'ReturnMailIndicator', 'bit', 'NULL', nil],
      ['GroupId', 'GroupId', 'int', 'NULL', nil],
      ['OcrBypass', 'OcrBypass', 'bit', 'NULL', nil],
      ['TaskOverride', 'TaskOverride', 'bit', 'NULL', nil],
      ['ImageCount', 'ImageCount', 'int', 'NULL', nil],
      ['CaseNumber', 'CaseNumber', 'varchar(255)', 'NULL', nil],
      ['DocumentType', 'DocumentType', 'varchar(255)', 'NULL', nil],
      ['DocumentId', 'DocumentId', 'varchar(255)', 'NULL', nil],
      ['FirstUpload', 'FirstUpload', 'bit', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'calsaws',
        table: 'ExportDocument',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
