# frozen_string_literal: true

[
  'Calsaws_triggeredevents',
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
      table: 'TriggeredEvents',
      local: 'calsaws_triggeredevents.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['EventId', 'EventId', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['TriggerName', 'TriggerName', 'nvarchar(255)', 'NULL', nil],
      ['TriggeredAction', 'TriggeredAction', 'nvarchar(255)', 'NULL', nil],
      ['OriginalStatus', 'OriginalStatus', 'int', 'NULL', nil],
      ['ExportDocumentId', 'ExportDocumentId', 'int', 'NULL', nil],
      ['DateCreated', 'DateCreated', 'datetime', 'NULL', nil],
      ['BarcodeValue', 'BarcodeValue', 'nvarchar(255)', 'NULL', nil],
      ['FilePath', 'FilePath', 'nvarchar(255)', 'NULL', nil],
      ['ImageCount', 'ImageCount', 'int', 'NULL', nil],
      ['JobName', 'JobName', 'nvarchar(255)', 'NULL', nil],
      ['OperatorName', 'OperatorName', 'nvarchar(255)', 'NULL', nil],
      ['NOTES', 'NOTES', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'calsaws',
        table: 'TriggeredEvents',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
