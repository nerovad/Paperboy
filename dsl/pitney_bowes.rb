# frozen_string_literal: true

[
  'PitneyBowes',
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
      name: 'mail_center_and_warehousing'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/pitney_bowes.xlsx',
      local: 'pitney_bowes.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['shipment_create_date',             'shipment_create_date',             'nvarchar(max)', 'NULL', nil],
      ['product_name',                     'product_name',                     'nvarchar(max)', 'NULL', nil],
      ['shipment',                         'shipment',                         'nvarchar(max)', 'NULL', nil],
      ['tracking',                         'tracking',                         'nvarchar(max)', 'NULL', nil],
      ['carrier_name',                     'carrier_name',                     'nvarchar(max)', 'NULL', nil],
      ['carrier_service',                  'carrier_service',                  'nvarchar(max)', 'NULL', nil],
      ['weight',                           'weight',                           'nvarchar(max)', 'NULL', nil],
      ['destination_zip',                  'destination_zip',                  'nvarchar(max)', 'NULL', nil],
      ['memoreference_onejob_id_2',        'memoreference_onejob_id_2',        'nvarchar(max)', 'NULL', nil],
      ['reference_twodepartment',          'reference_twodepartment',          'nvarchar(max)', 'NULL', nil],
      ['reference_threeinvoice',           'reference_threeinvoice',           'nvarchar(max)', 'NULL', nil],
      ['shipper_referencejob_id_1',        'shipper_referencejob_id_1',        'nvarchar(max)', 'NULL', nil],
      ['piece_count',                      'piece_count',                      'nvarchar(max)', 'NULL', nil],
      ['addl_surcharges_name',             'addl_surcharges_name',             'nvarchar(max)', 'NULL', nil],
      ['base_amount',                      'base_amount',                      'nvarchar(max)', 'NULL', nil],
      ['extra_services_surcharges_amount', 'extra_services_surcharges_amount', 'nvarchar(max)', 'NULL', nil],
      ['total_amount',                     'total_amount',                     'nvarchar(max)', 'NULL', nil],
      ['addl_surcharges_amount',           'addl_surcharges_amount',           'nvarchar(max)', 'NULL', nil],
      ['refund_amount',                    'refund_amount',                    'nvarchar(max)', 'NULL', nil],
      ['addl_surcharge_refund',            'addl_surcharge_refund',            'nvarchar(max)', 'NULL', nil],
      ['carrier_adjustment_amount',        'carrier_adjustment_amount',        'nvarchar(max)', 'NULL', nil],
      ['total_chargeback_amount',          'total_chargeback_amount',          'nvarchar(max)', 'NULL', nil],
      ['realized_savings',                 'realized_savings',                 'nvarchar(max)', 'NULL', nil],
      ['sender_name',                      'sender_name',                      'nvarchar(max)', 'NULL', nil],
      ['recipient_name',                   'recipient_name',                   'nvarchar(max)', 'NULL', nil],
      ['cost_account_name',                'cost_account_name',                'nvarchar(max)', 'NULL', nil],
      ['cost_account_code',                'cost_account_code',                'nvarchar(max)', 'NULL', nil],
      ['estimated_delivery_date',          'estimated_delivery_date',          'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'pitney_bowes',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
