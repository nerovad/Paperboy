# frozen_string_literal: true

[
  'Paperboy_dev_submission_comments',
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
      table: 'submission_comments',
      local: 'paperboy_dev_submission_comments.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['commentable_type', 'commentable_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['commentable_id', 'commentable_id', 'bigint', 'NOT NULL', nil],
      ['author_id', 'author_id', 'nvarchar(4000)', 'NULL', nil],
      ['author_name', 'author_name', 'nvarchar(4000)', 'NULL', nil],
      ['body', 'body', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'submission_comments',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
