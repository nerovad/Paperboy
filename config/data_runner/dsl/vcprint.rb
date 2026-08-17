# frozen_string_literal: true

[
  'VCPrint',
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
    sop: {
      title: 'How to Download VCPrint Data',
      source_system: 'VCPrint',
      reference_url: 'https://vcprint/public/login',
      reference_path: :source_location,
      instructions: [
        'Sign in to VCPrint.',
        'Open the completed orders report and select the required reporting period.',
        'Export the report as a CSV file.',
        'Save the downloaded file as vcprint.csv in the DataRunner inbox.',
        'Verify vcprint.csv is current.'
      ]
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/vcprint.csv',
      local: 'vcprint.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['order_id',                        'order_id',                 'int',           'NULL', nil],
      ['order_name',                      'order_name',               'nvarchar(100)', 'NULL', nil],
      ['order_status',                    nil,                        'nvarchar(max)', 'NULL', nil],
      ['user_id',                         nil,                        'nvarchar(max)', 'NULL', nil],
      ['skin',                            nil,                        'nvarchar(max)', 'NULL', nil],
      ['activity',                        'activity',                 'nvarchar(50)',  'NULL', nil],
      ['budget_unit',                     'budget_unit',              'nvarchar(4)',   'NULL', nil],
      ['function',                        'function',                 'nvarchar(50)',  'NULL', nil],
      ['program',                         'program',                  'nvarchar(50)',  'NULL', nil],
      ['form_number',                     'form_number',              'nvarchar(100)', 'NULL', nil],
      ['item',                            'item',                     'nvarchar(150)', 'NULL', nil],
      ['pdf_pages',                       'pdf_pages',                'int',           'NULL', nil],
      ['ordered_on_behalf',               nil,                        'nvarchar(max)', 'NULL', nil],
      ['order_placer',                    nil,                        'nvarchar(max)', 'NULL', nil],
      ['requested',                       nil,                        'nvarchar(max)', 'NULL', nil],
      ['due',                             nil,                        'nvarchar(max)', 'NULL', nil],
      ['field_removed',                   nil,                        'nvarchar(max)', 'NULL', nil],
      ['item_impressions',                'item_impressions',         'int',           'NULL', nil],
      ['printing_cost',                   'printing_cost',            'float',         'NULL', nil],
      ['print_queue',                     nil,                        'nvarchar(max)', 'NULL', nil],
      ['job_status',                      nil,                        'nvarchar(max)', 'NULL', nil],
      ['completed',                       'completed',                'datetime2(7)',  'NULL', nil],
      ['ready_to_ship_date',              nil,                        'nvarchar(max)', 'NULL', nil],
      ['recipient',                       'recipient',                'nvarchar(50)',  'NULL', nil],
      ['ship_location',                   'ship_location',            'nvarchar(50)',  'NULL', nil],
      ['is_inventory_item',               'is_inventory_item',        'nvarchar(1)',   'NULL', nil],
      ['source',                          nil,                        'nvarchar(max)', 'NULL', nil],
      ['requested_action',                nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute',               nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_2',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_3',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_4',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_5',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_6',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_7',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_8',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_9',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['product_attribute_10',            nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_address_addr_line_1',        nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_address_addr_line_2',        nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_address_addr_line_3',        nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_city',                       nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_state',                      nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_zip',                        nil,                        'nvarchar(max)', 'NULL', nil],
      ['ship_country',                    nil,                        'nvarchar(max)', 'NULL', nil],
      ['shipping_method',                 nil,                        'nvarchar(max)', 'NULL', nil],
      ['approval_printing_cost_estimate', nil,                        'nvarchar(max)', 'NULL', nil],
      ['ordering_printing_cost_estimate', nil,                        'nvarchar(max)', 'NULL', nil],
      ['order_submitted',                 nil,                        'nvarchar(max)', 'NULL', nil],
      ['production_received_date',        nil,                        'nvarchar(max)', 'NULL', nil],
      ['user_domain',                     'user_domain',              'nvarchar(50)',  'NULL', nil],
      ['order_placer_domain',             'order_placer_domain_name', 'nvarchar(50)',  'NULL', nil],
      ['company',                         'company',                  'nvarchar(50)',  'NULL', nil],
      ['department',                      'department',               'nvarchar(100)', 'NULL', nil],
      ['activity_split',                  nil,                        'nvarchar(max)', 'NULL', nil],
      ['budget_unit_split',               nil,                        'nvarchar(max)', 'NULL', nil],
      ['function_split',                  nil,                        'nvarchar(max)', 'NULL', nil],
      ['program_split',                   nil,                        'nvarchar(max)', 'NULL', nil],
      ['activity_total_split',            nil,                        'nvarchar(max)', 'NULL', nil],
      ['budget_unit_total_split',         nil,                        'nvarchar(max)', 'NULL', nil],
      ['function_total_split',            nil,                        'nvarchar(max)', 'NULL', nil],
      ['program_total_split',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['file_name',                       'file_name',                'nvarchar(150)', 'NULL', nil],
      ['entitlement',                     'entitlement',              'nvarchar(150)', 'NULL', nil],
      ['customer',                        'customer',                 'nvarchar(50)',  'NULL', nil],
      ['order_original_site',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['item_print_site',                 nil,                        'nvarchar(max)', 'NULL', nil],
      ['workgroup',                       nil,                        'nvarchar(max)', 'NULL', nil],
      ['folder',                          nil,                        'nvarchar(max)', 'NULL', nil],
      ['activity_description',            nil,                        'nvarchar(max)', 'NULL', nil],
      ['budget_unit_description',         nil,                        'nvarchar(max)', 'NULL', nil],
      ['function_description',            nil,                        'nvarchar(max)', 'NULL', nil],
      ['program_description',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['approval_group_name',             nil,                        'nvarchar(max)', 'NULL', nil],
      ['item_quantity_pieces',            'item_quantity_pieces',     'int',           'NULL', nil],
      ['item_color_impressions',          'item_color_impressions',   'int',           'NULL', nil],
      ['item_bw_impressions',             'item_b_w_impressions',     'int',           'NULL', nil],
      ['item_2',                          'item1',                    'int',           'NULL', nil],
      ['recipient_2',                     'recipient1',               'int',           'NULL', nil],
      ['tracking_number',                 'tracking_number',          'varchar(250)',  'NULL', nil]

    ],

    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSAP2M',
        schema: 'dbo',
        table: '_stgVcPrint',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
