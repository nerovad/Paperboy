# frozen_string_literal: true

[
  'Paperboy_dev_injury_classification_views',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'injury_classification_views',
      local: 'paperboy_dev_injury_classification_views.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['injury_category_id', 'injury_category_id', 'bigint', 'NOT NULL', nil],
      ['injury_category_description', 'injury_category_description', 'nvarchar(max)', 'NOT NULL', nil],
      ['injury_classification_id', 'injury_classification_id', 'bigint', 'NOT NULL', nil],
      ['injury_classification_description', 'injury_classification_description', 'nvarchar(max)', 'NOT NULL', nil],
      ['sort_order', 'sort_order', 'int', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'injury_classification_views',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
