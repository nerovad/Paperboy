# frozen_string_literal: true

[
  'USPS',
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
      name: 'billing'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/usps.csv',
      local: 'usps.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'eps_transaction_number',           'transaction_number',               'int',          'NULL', nil ],
      [ 'transaction_datetime_et',          'transaction_date',                 'datetime',     'NULL', nil ],
      [ 'transaction_amount',               'transaction_amount',               'float',        'NULL', nil ],
      [ 'transaction_type',                 'transaction_type',                 'nvarchar(50)', 'NULL', nil ],
      [ 'refund_reason',                    'refund_reason',                    'nvarchar(50)', 'NULL', nil ],
      [ 'eps_account_number',               'eps_account_number',               'int',          'NULL', nil ],
      [ 'eps_account_nickname',             'eps_account_nickname',             'nvarchar(50)', 'NULL', nil ],
      [ 'class',                            'class',                            'nvarchar(50)', 'NULL', nil ],
      [ 'number_of_pieces',                 'number_of_pieces',                 'int',          'NULL', nil ],
      [ 'permit_holder_crid',               'permit_holder_crid',               'int',          'NULL', nil ],
      [ 'permit_number',                    'permit_number',                    'int',          'NULL', nil ],
      [ 'permit_type',                      'permit_type',                      'nvarchar(50)', 'NULL', nil ],
      [ 'shipper_business_location',        'shipper_business_location',        'nvarchar(50)', 'NULL', nil ],
      [ 'publication_number',               'publication_number',               'tinyint',      'NULL', nil ],
      [ 'citystate_of_permit',              'city_state_of_permit',             'nvarchar(50)', 'NULL', nil ],
      [ 'mailing_city',                     'mailing_city',                     'nvarchar(50)', 'NULL', nil ],
      [ 'mailing_state',                    'mailing_state',                    'nvarchar(50)', 'NULL', nil ],
      [ 'zip_of_verification',              'zip_of_verification',              'int',          'NULL', nil ],
      [ 'customer_reference_id',            'customer_reference_id',            'nvarchar(50)', 'NULL', nil ],
      [ 'job_id',                           'job_id',                           'nvarchar(50)', 'NULL', nil ],
      [ 'user_license_code',                'user_license_code',                'nvarchar(50)', 'NULL', nil ],
      [ 'spoilage',                         'spoilage',                         'tinyint',      'NULL', nil ],
      [ 'number_of_copies',                 'number_of_copies',                 'tinyint',      'NULL', nil ],
      [ 'mailing_date',                     'mailing_date',                     'date',         'NULL', nil ],
      [ 'edoc_submitter_crid',              'edoc_submitter_crid',              'int',          'NULL', nil ],
      [ 'edoc_submitter_crid_company_name', 'edoc_submitter_crid_company_name', 'nvarchar(50)', 'NULL', nil ],
      [ 'postage_statement_number',         'postage_statement_number',         'int',          'NULL', nil ],
      [ 'pic',                              'pic',                              'nvarchar(50)', 'NULL', nil ],
      [ 'sku',                              'sku',                              'nvarchar(50)', 'NULL', nil ],
      [ 'unique_package_id',                'unique_package_id',                'nvarchar(50)', 'NULL', nil ],
      [ 'efn',                              'efn',                              'nvarchar(50)', 'NULL', nil ],
      [ 'manifest_package_id',              'manifest_package_id',              'nvarchar(50)', 'NULL', nil ],
      [ 'assessment_type',                  'assessment_type',                  'nvarchar(50)', 'NULL', nil ],
      [ 'monthly_adjustment_id',            'monthly_adjustment_id',            'nvarchar(50)', 'NULL', nil ],
      [ 'assessment_details',               'assessment_details',               'nvarchar(50)', 'NULL', nil ],
      [ 'unused_label_fee_amount',          'unused_label_fee_amount',          'nvarchar(50)', 'NULL', nil ],
      [ 'mailer_review_request_id',         'mailer_review_request_id',         'nvarchar(50)', 'NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSAP2M',
        schema: 'dbo',
        table: '_stgUspsPostage',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
