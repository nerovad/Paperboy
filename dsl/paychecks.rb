# frozen_string_literal: true

[
  'Paychecks',
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
      name: 'human_resources'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/paychecks.xlsx',
      local: 'paychecks.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 1,
      data_row: 2
    },
    header: [

      [ 'use_hash_a_use_hash_a1', 'employee_id',      'nvarchar(6)',   'NOT NULL', nil ],
      [ 'position',               'position',         'nvarchar(8)',   'NOT NULL', nil ],
      [ 'pay_period_end',         'pay_period_end',   'date',          'NOT NULL', nil ],
      [ 'earn_code',              'earn_code',        'nvarchar(4)',   'NULL',     nil ],
      [ 'descr',                  'description',      'nvarchar(50)',  'NOT NULL', nil ],
      [ 'dept_id',                'unit_id',          'nvarchar(4)',   'NOT NULL', nil ],
      [ 'glexpense',              'glexpense',        'nvarchar(4)',   'NULL',     nil ],
      [ 'name',                   'name',             'nvarchar(50)',  'NOT NULL', nil ],
      [ 'hours',                  'hours',            'decimal(9,2)',  'NOT NULL', nil ],
      [ 'amount',                 'amount',           'decimal(12,2)', 'NOT NULL', nil ],
      [ 'hrly_rate',              'hourly_rate',      'decimal(12,4)', 'NOT NULL', nil ],
      [ 'pay_run_id',             'pay_run_id',       'nvarchar(7)',   'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'paychecks',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
