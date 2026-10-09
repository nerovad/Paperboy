# frozen_string_literal: true

[
  'Gsap2m_stvcprint_backup',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: '_stVcPrint_Backup',
      local: 'gsap2m_stvcprint_backup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['order_id', 'order_id', 'int', 'NULL', nil],
      ['order_name', 'order_name', 'nvarchar(100)', 'NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(4)', 'NULL', nil],
      ['activity', 'activity', 'nvarchar(50)', 'NULL', nil],
      ['function', 'function', 'nvarchar(50)', 'NULL', nil],
      ['program', 'program', 'nvarchar(50)', 'NULL', nil],
      ['phase', 'phase', 'nvarchar(50)', 'NULL', nil],
      ['task', 'task', 'nvarchar(50)', 'NULL', nil],
      ['form_number', 'form_number', 'nvarchar(100)', 'NULL', nil],
      ['item', 'item', 'nvarchar(150)', 'NULL', nil],
      ['pdf_pages', 'pdf_pages', 'int', 'NULL', nil],
      ['item_impressions', 'item_impressions', 'int', 'NULL', nil],
      ['printing_cost', 'printing_cost', 'float', 'NULL', nil],
      ['completed', 'completed', 'datetime2(7)', 'NULL', nil],
      ['recipient', 'recipient', 'nvarchar(50)', 'NULL', nil],
      ['ship_location', 'ship_location', 'nvarchar(50)', 'NULL', nil],
      ['is_inventory_item', 'is_inventory_item', 'nvarchar(1)', 'NULL', nil],
      ['user_domain', 'user_domain', 'nvarchar(50)', 'NULL', nil],
      ['order_placer_domain_name', 'order_placer_domain_name', 'nvarchar(50)', 'NULL', nil],
      ['company', 'company', 'nvarchar(50)', 'NULL', nil],
      ['department', 'department', 'nvarchar(100)', 'NULL', nil],
      ['file_name', 'file_name', 'nvarchar(150)', 'NULL', nil],
      ['entitlement', 'entitlement', 'nvarchar(150)', 'NULL', nil],
      ['customer', 'customer', 'nvarchar(50)', 'NULL', nil],
      ['item_quantity_pieces', 'item_quantity_pieces', 'int', 'NULL', nil],
      ['item_color_impressions', 'item_color_impressions', 'int', 'NULL', nil],
      ['item_b_w_impressions', 'item_b_w_impressions', 'int', 'NULL', nil],
      ['item1', 'item1', 'int', 'NULL', nil],
      ['recipient1', 'recipient1', 'int', 'NULL', nil],
      ['tracking_number', 'tracking_number', 'varchar(250)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: '_stVcPrint_Backup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
