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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/companions.csv',
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

      ['budget_1_job_id',                         'budget_1_job_id',                         'varchar(16)',   'NULL',                   nil],
      ['budget_2_budget_unit',                    'budget_2_budget_unit',                    'bigint',        'NULL',                   nil],
      ['budget_3_activity',                       'budget_3_activity',                       'varchar(100)',  'NULL',                   nil],
      ['budget_4',                                'budget_4',                                'varchar(100)',  'NULL',                   nil],
      ['case_number',                             'case_number',                             'varchar(100)',  'NULL',                   nil],
      ['customer_id',                             'customer_id',                             'varchar(100)',  'NULL',                   nil],
      ['district',                                'district',                                'varchar(100)',  'NULL',                   nil],
      ['document_number',                         'document_number',                         'varchar(100)',  'NULL',                   nil],
      ['document_title',                          'document_title',                          'varchar(100)',  'NULL',                   nil],
      ['postal_address',                          'postal_address',                          'varchar(200)',  'NULL',                   nil],
      ['postal_addresslast_line',                 'postal_address_last_line',                'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_1',                    'postal_address_line_1',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_2',                    'postal_address_line_2',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_3',                    'postal_address_line_3',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_4',                    'postal_address_line_4',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_5',                    'postal_address_line_5',                   'varchar(100)',  'NULL',                   nil],
      ['postal_addressline_6',                    'postal_address_line_6',                   'varchar(100)',  'NULL',                   nil],
      ['statement_number',                        'statement_number',                        'varchar(100)',  'NULL',                   nil],
      ['total_amount',                            'total_amount',                            'varchar(100)',  'NULL',                   nil],
      ['aims_job_id',                             'aims_job_id',                             'varchar(100)',  'NULL',                   nil],
      ['aims_mail_piece_id',                      'aims_mail_piece_id',                      'varchar(100)',  'NULL',                   nil],
      ['aims_status',                             'aims_status',                             'varchar(100)',  'NULL',                   nil],
      ['batch_id',                                'batch_id',                                'bigint',        'NULL',                   nil],
      ['communication_piece_file_name',           'communication_piece_file_name',           'varchar(100)',  'NULL',                   nil],
      ['communication_piece_id',                  'communication_piece_id',                  'bigint',        'NULL',                   nil],
      ['communication_piece_number',              'communication_piece_number',              'bigint',        'NULL',                   nil],
      ['communication_profile_name',              'communication_profile_name',              'varchar(100)',  'NULL',                   nil],
      ['container_file_name',                     'container_file_name',                     'varchar(100)',  'NULL',                   nil],
      ['container_number',                        'container_number',                        'bigint',        'NULL',                   nil],
      ['creation_date',                           'creation_date',                           'varchar(100)',  'NULL',                   nil],
      ['delivery_type',                           'delivery_type',                           'varchar(100)',  'NULL',                   nil],
      ['document_profile_names',                  'document_profile_names',                  'varchar(100)',  'NULL',                   nil],
      ['enclosures_added',                        'enclosures_added',                        'bigint',        'NULL',                   nil],
      ['envelope_format',                         'envelope_format',                         'bigint',        'NULL',                   nil],
      ['envelope_name',                           'envelope_name',                           'varchar(max)',  'NULL',                   nil],
      ['envelope_number',                         'envelope_number',                         'bigint',        'NULL',                   nil],
      ['envelope_size',                           'envelope_size',                           'decimal(18,10)', 'NULL',                   nil],
      ['file_counter',                            'file_counter',                            'bigint',        'NULL',                   nil],
      ['input_file_names',                        'input_file_names',                        'varchar(255)',  'NULL',                   nil],
      ['input_names',                             'input_names',                             'varchar(100)',  'NULL',                   nil],
      ['number_of_pages',                         'number_of_pages',                         'bigint',        'NULL',                   nil],
      ['output_file_name',                        'output_file_name',                        'varchar(100)',  'NULL',                   nil],
      ['output_name',                             'output_name',                             'varchar(100)',  'NULL',                   nil],
      ['print_on_both_sides',                     'print_on_both_sides',                     'varchar(100)',  'NULL',                   nil],
      ['print_or_send_time',                      'print_or_send_time',                      'varchar(100)',  'NULL',                   nil],
      ['priority',                                'priority',                                'varchar(100)',  'NULL',                   nil],
      ['production_workflow_name',                'production_workflow_name',                'varchar(100)',  'NULL',                   nil],
      ['run_production_username',                 'run_production_username',                 'varchar(100)',  'NULL',                   nil],
      ['sorting_parameters',                      'sorting_parameters',                      'varchar(100)',  'NULL',                   nil],
      ['sorting_type',                            'sorting_type',                            'varchar(100)',  'NULL',                   nil],
      ['thickness',                               'thickness',                               'float',         'NULL',                   nil],
      ['total_communication_pieces_in_container', 'total_communication_pieces_in_container', 'bigint',        'NULL',                   nil],
      ['total_documents',                         'total_documents',                         'bigint',        'NULL',                   nil],
      ['total_envelopes',                         'total_envelopes',                         'bigint',        'NULL',                   nil],
      ['total_pages_in_batch',                    'total_pages_in_batch',                    'bigint',        'NULL',                   nil],
      ['total_pages_in_communication_piece',      'total_pages_in_communication_piece',      'bigint',        'NULL',                   nil],
      ['total_pages_in_container',                'total_pages_in_container',                'bigint',        'NULL',                   nil],
      ['total_sheets',                            'total_sheets',                            'bigint',        'NULL',                   nil],
      ['volume_used',                             'volume_used',                             'bigint',        'NULL',                   nil],
      ['weight',                                  'weight',                                  'float',         'NULL',                   nil],
      ['omsnumber',                               'omsnumber',                               'int',           'NULL',                   nil],
      [nil,                                       'sourcefilename',                          'nvarchar(max)', 'NULL',                   nil],
      [nil,                    'id',                   'int',           'IDENTITY(0,1) NOT NULL', nil],
      ['importdatetime',                          'importdatetime',                          'datetime2(7)',  'NULL',                   nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'companions',
        inject: {
          mode: :append,
          reject_existing: %w[omsnumber]
        }
      }
    ]
  }
]
