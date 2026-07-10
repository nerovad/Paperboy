# frozen_string_literal: true

[
  'Companions',
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
      name: 'print_2_mail_billing_data'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/companions.csv',
      local: 'companions.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [
      [ 'budget_1_job_id',                         'job_id',         'varchar(16)',   'NULL',                   nil ],
      [ 'Budget 2 - Budget Unit',                  nil,              'bigint',        'NULL',                   nil ],
      [ 'Budget 3 - Activity',                     nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Budget 4',                                nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Case Number',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Customer ID',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'District',                                nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Document Number',                         nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Document Title',                          nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address',                          nil,              'varchar(200)',  'NULL',                   nil ],
      [ 'Postal Address Last Line',                nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 1',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 2',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 3',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 4',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 5',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Postal Address Line 6',                   nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Statement Number',                        nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Total Amount',                            nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'AIMS job ID',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'AIMS mail piece ID',                      nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'AIMS status',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Batch ID',                                nil,              'bigint',        'NULL',                   nil ],
      [ 'Communication piece file name',           nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Communication piece ID',                  nil,              'bigint',        'NULL',                   nil ],
      [ 'Communication piece number',              nil,              'bigint',        'NULL',                   nil ],
      [ 'Communication profile name',              nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Container file name',                     nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Container number',                        nil,              'bigint',        'NULL',                   nil ],
      [ 'Creation date',                           nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Delivery type',                           nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Document profile names',                  nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Enclosures added',                        nil,              'bigint',        'NULL',                   nil ],
      [ 'Envelope format',                         nil,              'bigint',        'NULL',                   nil ],
      [ 'Envelope name',                           nil,              'varchar(max)',  'NULL',                   nil ],
      [ 'Envelope number',                         nil,              'bigint',        'NULL',                   nil ],
      [ 'Envelope size',                           nil,              'bigint',        'NULL',                   nil ],
      [ 'File counter',                            nil,              'bigint',        'NULL',                   nil ],
      [ 'Input file names',                        nil,              'varchar(255)',  'NULL',                   nil ],
      [ 'Input names',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Number of pages',                         nil,              'bigint',        'NULL',                   nil ],
      [ 'Output file name',                        nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Output name',                             nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Print on both sides',                     nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Print or send time',                      nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Priority',                                nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Production workflow name',                nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Run production username',                 nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Sorting parameters',                      nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Sorting type',                            nil,              'varchar(100)',  'NULL',                   nil ],
      [ 'Thickness',                               nil,              'float',         'NULL',                   nil ],
      [ 'Total communication pieces in container', nil,              'bigint',        'NULL',                   nil ],
      [ 'Total documents',                         nil,              'bigint',        'NULL',                   nil ],
      [ 'Total envelopes',                         nil,              'bigint',        'NULL',                   nil ],
      [ 'Total pages in batch',                    nil,              'bigint',        'NULL',                   nil ],
      [ 'Total pages in communication piece',      nil,              'bigint',        'NULL',                   nil ],
      [ 'Total pages in container',                nil,              'bigint',        'NULL',                   nil ],
      [ 'Total sheets',                            nil,              'bigint',        'NULL',                   nil ],
      [ 'Volume used',                             nil,              'bigint',        'NULL',                   nil ],
      [ 'Weight',                                  nil,              'float',         'NULL',                   nil ],
      [ 'omsnumber',                               'oms_number',     'int',           'NULL',                   nil ],
      [ 'SourceFileName',                          nil,              'nvarchar(max)', 'NULL',                   nil ],
      [ nil,                                       'id',             'bigint',        'IDENTITY(0,1) NOT NULL', nil ],
      [ 'importdatetime',                          'import_date_time', 'datetime2(7)',  'NULL',                   nil ]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'companions',
        inject: {
          mode: :append
        }
      }
    ]
  }
]
