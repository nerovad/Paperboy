# frozen_string_literal: true

[
  'Warehousing',
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
      name: 'mail_center_and_warehousing'
    },
    source: {
      location: 'warehousing.csv',
      local: 'warehousing.csv',
      format: :csv,
      strategy: :script,
      script: {
        path: 'script/download/warehousing.rb',
        args: [ 'ALL' ]
      }
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'type',        'type',        'varchar(3)',  'NOT NULL', nil ],
      [ 'cunit',       'cunit',       'varchar(4)',  'NOT NULL', nil ],
      [ 'cobject',     'cobject',     'int',         'NOT NULL', 0 ],
      [ 'cactivity',   'cactivity',   'varchar(4)',  'NULL',     nil ],
      [ 'cfunction',   'cfunction',   'varchar(4)',  'NULL',     nil ],
      [ 'cprogram',    'cprogram',    'varchar(10)', 'NULL',     nil ],
      [ 'cphase',      'cphase',      'varchar(6)',  'NULL',     nil ],
      [ 'ctask',       'ctask',       'varchar(4)',  'NULL',     nil ],
      [ 'amount',      'amount',      'float',       'NOT NULL', 0.0 ],
      [ 'sunit',       'sunit',       'varchar(4)',  'NOT NULL', nil ],
      [ 'sobject',     'sobject',     'int',         'NOT NULL', 0 ],
      [ 'sactivity',   'sactivity',   'varchar(4)',  'NULL',     nil ],
      [ 'sfunction',   'sfunction',   'varchar(4)',  'NULL',     nil ],
      [ 'sprogram',    'sprogram',    'varchar(10)', 'NULL',     nil ],
      [ 'sphase',      'sphase',      'varchar(6)',  'NULL',     nil ],
      [ 'stask',       'stask',       'varchar(4)',  'NULL',     nil ],
      [ 'posting_ref', 'posting_ref', 'varchar(20)', 'NOT NULL', nil ],
      [ 'service',     'service',     'varchar(15)', 'NOT NULL', nil ],
      [ 'date',        'date',        'date',        'NOT NULL', nil ],
      [ 'doc_nmbr',    'doc_nmbr',    'varchar(50)', 'NULL',     nil ],
      [ 'description', 'description', 'varchar(50)', 'NULL',     nil ],
      [ 'other1',      'other1',      'varchar(50)', 'NULL',     nil ],
      [ 'other2',      'other2',      'varchar(50)', 'NULL',     nil ],
      [ 'other3',      'other3',      'varchar(50)', 'NULL',     nil ],
      [ 'quantity',    'quantity',    'float',       'NOT NULL', 0.0 ],
      [ 'rate',        'rate',        'float',       'NOT NULL', 0.0 ],
      [ 'cost',        'cost',        'float',       'NOT NULL', 0.0 ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'warehousing',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
