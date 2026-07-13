# frozen_string_literal: true

[
  'InjuryClassificationViews',
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
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/injury_classifications.xlsx',
      local: 'injury_classifications.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'injury_classification_views.csv',
    to_csv: {
      sheet: 2,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['category_id',                            'injury_category_id',                'bigint',        'NOT NULL', nil],
      ['injury_category_description',            'injury_category_description',       'nvarchar(max)', 'NOT NULL', nil],
      ['injury_classification_id',               'injury_classification_id',          'bigint',        'NOT NULL', nil],
      ['injury_classificaiion_description',      'injury_classification_description', 'nvarchar(max)', 'NOT NULL', nil],
      ['sort_order',                             'sort_order',                        'int',           'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'injury_classification_views',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
