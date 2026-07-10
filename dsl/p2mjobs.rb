# frozen_string_literal: true

[
  'P2mjobs',
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
      name: 'print_2_mail'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/p2mjobs.csv',
      local: 'p2mjobs.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'fyear',                     'fyear',                     'nvarchar(50)',  'NOT NULL', nil ],
      [ 'job_id',                    'job_id',                    'nvarchar(50)',  'NOT NULL', nil ],
      [ 'oms_document_profile',      'oms_document_profile',      'nvarchar(100)', 'NOT NULL', nil ],
      [ 'oms_communication_profile', 'oms_communication_profile', 'nvarchar(50)',  'NOT NULL', nil ],
      [ 'oms_production_workflow',   'oms_production_workflow',   'nvarchar(50)',  'NOT NULL', nil ],
      [ 'media_channel',             'media_channel',             'nvarchar(50)',  'NOT NULL', nil ],
      [ 'job_description',           'job_description',           'nvarchar(100)', 'NOT NULL', nil ],
      [ 'graphic_unit_cost',         'graphic_unit_cost',         'float',         'NOT NULL', nil ],
      [ 'p2munitcost',               'p2munitcost',               'float',         'NOT NULL', nil ],
      [ 'full_postage_rate',         'full_postage_rate',         'float',         'NOT NULL', nil ],
      [ 'active',                    'active',                    'smallint',      'NOT NULL', nil ],
      [ 'agency',                    'agency',                    'nvarchar(50)',  'NOT NULL', nil ],
      [ 'department',                'department',                'nvarchar(50)',  'NOT NULL', nil ],
      [ 'budget_unit',               'budget_unit',               'nvarchar(4)',   'NOT NULL', nil ],
      [ 'object',                    'object',                    'nvarchar(4)',   'NOT NULL', nil ],
      [ 'activity',                  'activity',                  'nvarchar(4)',   'NOT NULL', nil ],
      [ 'function',                  'function',                  'nvarchar(4)',   'NOT NULL', nil ],
      [ 'cproj',                     'cproj',                     'nvarchar(10)',  'NULL',     nil ],
      [ 'program',                   'program',                   'nvarchar(10)',  'NULL',     nil ],
      [ 'phase',                     'phase',                     'nvarchar(6)',   'NULL',     nil ],
      [ 'task',                      'task',                      'nvarchar(4)',   'NULL',     nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'p2mjobs',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
