# frozen_string_literal: true

[
  'Gsap2m_vcprint',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'VcPrint',
      local: 'gsap2m_vcprint.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Order_ID', 'Order_ID', 'int', 'NULL', nil],
      ['Order_Name', 'Order_Name', 'nvarchar(100)', 'NULL', nil],
      ['Budget_Unit', 'Budget_Unit', 'nvarchar(4)', 'NULL', nil],
      ['Activity', 'Activity', 'nvarchar(50)', 'NULL', nil],
      ['Function', 'Function', 'nvarchar(50)', 'NULL', nil],
      ['Program', 'Program', 'nvarchar(50)', 'NULL', nil],
      ['Phase', 'Phase', 'nvarchar(50)', 'NULL', nil],
      ['Task', 'Task', 'nvarchar(50)', 'NULL', nil],
      ['Form_Number', 'Form_Number', 'nvarchar(100)', 'NULL', nil],
      ['Item', 'Item', 'nvarchar(150)', 'NULL', nil],
      ['PDF_Pages', 'PDF_Pages', 'int', 'NULL', nil],
      ['Item_Impressions', 'Item_Impressions', 'int', 'NULL', nil],
      ['Printing_Cost', 'Printing_Cost', 'float', 'NULL', nil],
      ['Completed', 'Completed', 'datetime2(7)', 'NULL', nil],
      ['Recipient', 'Recipient', 'nvarchar(50)', 'NULL', nil],
      ['Ship_Location', 'Ship_Location', 'nvarchar(50)', 'NULL', nil],
      ['Is_Inventory_Item', 'Is_Inventory_Item', 'nvarchar(1)', 'NULL', nil],
      ['User_Domain', 'User_Domain', 'nvarchar(50)', 'NULL', nil],
      ['Order_Placer_Domain_Name', 'Order_Placer_Domain_Name', 'nvarchar(50)', 'NULL', nil],
      ['Company', 'Company', 'nvarchar(50)', 'NULL', nil],
      ['Department', 'Department', 'nvarchar(100)', 'NULL', nil],
      ['File_Name', 'File_Name', 'nvarchar(150)', 'NULL', nil],
      ['Entitlement', 'Entitlement', 'nvarchar(150)', 'NULL', nil],
      ['Customer', 'Customer', 'nvarchar(50)', 'NULL', nil],
      ['Item_Quantity_Pieces', 'Item_Quantity_Pieces', 'int', 'NULL', nil],
      ['Item_Color_Impressions', 'Item_Color_Impressions', 'int', 'NULL', nil],
      ['Item_B_W_Impressions', 'Item_B_W_Impressions', 'int', 'NULL', nil],
      ['Item1', 'Item1', 'int', 'NULL', nil],
      ['Recipient1', 'Recipient1', 'int', 'NULL', nil],
      ['Tracking_Number', 'Tracking_Number', 'varchar(250)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'VcPrint',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
