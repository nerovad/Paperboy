# frozen_string_literal: true

[
  'Companions',
  {
    steps: {
      manual: {
        enabled: false,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'print_2_mail_billing_data'
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'companions.csv'),
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

      ['budget_1_job_id', 'Budget 1 - Job ID',                         'varchar(16)',   'NULL',                   nil],
      ['budget_2_budget_unit', 'Budget 2 - Budget Unit',                    'bigint',        'NULL',                   nil],
      ['budget_3_activity', 'Budget 3 - Activity',                       'varchar(100)',  'NULL',                   nil],
      ['budget_4', 'Budget 4',                                'varchar(100)',  'NULL',                   nil],
      ['case_number', 'Case Number',                             'varchar(100)',  'NULL',                   nil],
      ['customer_id', 'Customer ID',                             'varchar(100)',  'NULL',                   nil],
      ['district', 'District',                                'varchar(100)',  'NULL',                   nil],
      ['document_number', 'Document Number',                         'varchar(100)',  'NULL',                   nil],
      ['document_title', 'Document Title',                          'varchar(100)',  'NULL',                   nil],
      ['postal_address', 'Postal Address',                          'varchar(200)',  'NULL',                   nil],
      ['postal_addresslast_line', 'Postal Address Last Line',                'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_1', 'Postal Address Line 1',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_2', 'Postal Address Line 2',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_3', 'Postal Address Line 3',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_4', 'Postal Address Line 4',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_5', 'Postal Address Line 5',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_6', 'Postal Address Line 6',                   'varchar(100)',  'NULL',                   nil],
      ['statement_number', 'Statement Number',                        'varchar(100)',  'NULL',                   nil],
      ['total_amount', 'Total Amount',                            'varchar(100)',  'NULL',                   nil],
      ['aims_job_id', 'AIMS job ID',                             'varchar(100)',  'NULL',                   nil],
      ['aims_mail_piece_id', 'AIMS mail piece ID',                      'varchar(100)',  'NULL',                   nil],
      ['aims_status', 'AIMS status',                             'varchar(100)',  'NULL',                   nil],
      ['batch_id', 'Batch ID',                                'bigint',        'NULL',                   nil],
      ['communication_piece_file_name', 'Communication piece file name',           'varchar(100)',  'NULL',                   nil],
      ['communication_piece_id', 'Communication piece ID',                  'bigint',        'NULL',                   nil],
      ['communication_piece_number', 'Communication piece number',              'bigint',        'NULL',                   nil],
      ['communication_profile_name', 'Communication profile name',              'varchar(100)',  'NULL',                   nil],
      ['container_file_name', 'Container file name',                     'varchar(100)',  'NULL',                   nil],
      ['container_number', 'Container number',                        'bigint',        'NULL',                   nil],
      ['creation_date', 'Creation date',                           'varchar(100)',  'NULL',                   nil],
      ['delivery_type', 'Delivery type',                           'varchar(100)',  'NULL',                   nil],
      ['document_profile_names', 'Document profile names',                  'varchar(100)',  'NULL',                   nil],
      ['enclosures_added', 'Enclosures added',                        'bigint',        'NULL',                   nil],
      ['envelope_format', 'Envelope format',                         'bigint',        'NULL',                   nil],
      ['envelope_name', 'Envelope name',                           'varchar(max)',  'NULL',                   nil],
      ['envelope_number', 'Envelope number',                         'bigint',        'NULL',                   nil],
      ['envelope_size', 'Envelope size',                           'bigint', 'NULL',                   nil],
      ['file_counter', 'File counter',                            'bigint',        'NULL',                   nil],
      ['input_file_names', 'Input file names',                        'varchar(255)',  'NULL',                   nil],
      ['input_names', 'Input names',                             'varchar(100)',  'NULL',                   nil],
      ['number_of_pages', 'Number of pages',                         'bigint',        'NULL',                   nil],
      ['output_file_name', 'Output file name',                        'varchar(100)',  'NULL',                   nil],
      ['output_name', 'Output name',                             'varchar(100)',  'NULL',                   nil],
      ['print_on_both_sides', 'Print on both sides',                     'varchar(100)',  'NULL',                   nil],
      ['print_or_send_time', 'Print or send time',                      'varchar(100)',  'NULL',                   nil],
      ['priority', 'Priority',                                'varchar(100)',  'NULL',                   nil],
      ['production_workflow_name', 'Production workflow name',                'varchar(100)',  'NULL',                   nil],
      ['run_production_username', 'Run production username',                 'varchar(100)',  'NULL',                   nil],
      ['sorting_parameters', 'Sorting parameters',                      'varchar(100)',  'NULL',                   nil],
      ['sorting_type', 'Sorting type',                            'varchar(100)',  'NULL',                   nil],
      ['thickness', 'Thickness',                               'float',         'NULL',                   nil],
      ['total_communication_pieces_in_container', 'Total communication pieces in container', 'bigint',        'NULL',                   nil],
      ['total_documents', 'Total documents',                         'bigint',        'NULL',                   nil],
      ['total_envelopes', 'Total envelopes',                         'bigint',        'NULL',                   nil],
      ['total_pages_in_batch', 'Total pages in batch',                    'bigint',        'NULL',                   nil],
      ['total_pages_in_communication_piece', 'Total pages in communication piece',      'bigint',        'NULL',                   nil],
      ['total_pages_in_container', 'Total pages in container',                'bigint',        'NULL',                   nil],
      ['total_sheets', 'Total sheets',                            'bigint',        'NULL',                   nil],
      ['volume_used', 'Volume used',                             'bigint',        'NULL',                   nil],
      ['weight', 'Weight',                                  'float',         'NULL',                   nil],
      ['omsnumber', 'OMSNumber',                               'int',           'NULL',                   nil],
      [nil,                                       'SourceFileName',                          'nvarchar(max)', 'NULL',                   nil],
      [nil,                    'ID',                   'int',           'IDENTITY(0,1) NOT NULL', nil],
      ['importdatetime', 'ImportDateTime',                          'datetime2(7)',  'NULL',                   nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'Companion',
        inject: {
          mode: :append,
          reject_existing: %w[OMSNumber]
        }
      }
    ]
  }
]
