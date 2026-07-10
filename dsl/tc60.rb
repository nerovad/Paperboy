# frozen_string_literal: true

[
  'Tc60',
  {
    steps: {
      enabled: false,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'billing_configuration'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/tc60.csv',
      local: 'tc60.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ nil,           'id',          'bigint',      'IDENTITY(1,1) NOT NULL', nil ],
      [ 'type',        'type',        'varchar(3)',  'NOT NULL',               nil ],
      [ 'cunit',       'cunit',       'varchar(4)',  'NOT NULL',               nil ],
      [ 'cobject',     'cobject',     'int',         'NOT NULL',               nil ],
      [ 'cactivity',   'cactivity',   'varchar(4)',  'NULL',                   nil ],
      [ 'cfunction',   'cfunction',   'varchar(4)',  'NULL',                   nil ],
      [ 'cprogram',    'cprogram',    'varchar(10)', 'NULL',                   nil ],
      [ 'cphase',      'cphase',      'varchar(6)',  'NULL',                   nil ],
      [ 'ctask',       'ctask',       'varchar(4)',  'NULL',                   nil ],
      [ 'amount',      'amount',      'float',       'NULL',                   '((0.0))' ],
      [ 'sunit',       'sunit',       'varchar(4)',  'NOT NULL',               nil ],
      [ 'sobject',     'sobject',     'int',         'NOT NULL',               nil ],
      [ 'sactivity',   'sactivity',   'varchar(4)',  'NULL',                   nil ],
      [ 'sfunction',   'sfunction',   'varchar(4)',  'NULL',                   nil ],
      [ 'sprogram',    'sprogram',    'varchar(10)', 'NULL',                   nil ],
      [ 'sphase',      'sphase',      'varchar(6)',  'NULL',                   nil ],
      [ 'stask',       'stask',       'varchar(4)',  'NULL',                   nil ],
      [ 'posting_ref', 'posting_ref', 'varchar(20)', 'NOT NULL',               nil ],
      [ 'service',     'service',     'varchar(15)', 'NOT NULL',               nil ],
      [ 'date',        'date',        'date',        'NOT NULL',               nil ],
      [ 'doc_nmbr',    'doc_nmbr',    'varchar(50)', 'NULL',                   nil ],
      [ 'description', 'description', 'varchar(50)', 'NULL',                   nil ],
      [ 'other1',      'other1',      'varchar(50)', 'NULL',                   nil ],
      [ 'other2',      'other2',      'varchar(50)', 'NULL',                   nil ],
      [ 'other3',      'other3',      'varchar(50)', 'NULL',                   nil ],
      [ 'quantity',    'quantity',    'float',       'NULL',                   '((0.0))' ],
      [ 'rate',        'rate',        'float',       'NULL',                   '((0.0))' ],
      [ 'cost',        'cost',        'float',       'NULL',                   nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSAP2M',
        schema: 'dbo',
        table: 'tc60',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
