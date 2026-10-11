# frozen_string_literal: true

[
  'Gsap2m_uspspostage_backup',
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
      table: 'UspsPostage_Backup',
      local: 'gsap2m_uspspostage_backup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['EPS_Transaction_Number', 'EPS_Transaction_Number', 'int', 'NULL', nil],
      ['Transaction_Date', 'Transaction_Date', 'datetime2(7)', 'NULL', nil],
      ['Transaction_Amount', 'Transaction_Amount', 'float', 'NULL', nil],
      ['Transaction_Type', 'Transaction_Type', 'nvarchar(50)', 'NULL', nil],
      ['Refund_Reason', 'Refund_Reason', 'nvarchar(50)', 'NULL', nil],
      ['EPS_Account_Number', 'EPS_Account_Number', 'int', 'NULL', nil],
      ['EPS_Account_Nickname', 'EPS_Account_Nickname', 'nvarchar(50)', 'NULL', nil],
      ['Class', 'Class', 'nvarchar(50)', 'NULL', nil],
      ['Number_of_Pieces', 'Number_of_Pieces', 'smallint', 'NULL', nil],
      ['Permit_Holder_CRID', 'Permit_Holder_CRID', 'int', 'NULL', nil],
      ['Permit_Number', 'Permit_Number', 'int', 'NULL', nil],
      ['Permit_Type', 'Permit_Type', 'nvarchar(50)', 'NULL', nil],
      ['Shipper_Business_Location', 'Shipper_Business_Location', 'nvarchar(50)', 'NULL', nil],
      ['Publication_Number', 'Publication_Number', 'tinyint', 'NULL', nil],
      ['City_State_of_Permit', 'City_State_of_Permit', 'nvarchar(50)', 'NULL', nil],
      ['Mailing_City', 'Mailing_City', 'nvarchar(50)', 'NULL', nil],
      ['Mailing_State', 'Mailing_State', 'nvarchar(50)', 'NULL', nil],
      ['ZIP_of_Verification', 'ZIP_of_Verification', 'int', 'NULL', nil],
      ['Customer_Reference_ID', 'Customer_Reference_ID', 'nvarchar(50)', 'NULL', nil],
      ['Job_ID', 'Job_ID', 'nvarchar(50)', 'NULL', nil],
      ['User_License_Code', 'User_License_Code', 'nvarchar(50)', 'NULL', nil],
      ['Spoilage', 'Spoilage', 'tinyint', 'NULL', nil],
      ['Number_of_Copies', 'Number_of_Copies', 'tinyint', 'NULL', nil],
      ['Mailing_Date', 'Mailing_Date', 'date', 'NULL', nil],
      ['eDoc_Submitter_Crid', 'eDoc_Submitter_Crid', 'int', 'NULL', nil],
      ['eDoc_Submitter_Crid_Company_Name', 'eDoc_Submitter_Crid_Company_Name', 'nvarchar(50)', 'NULL', nil],
      ['Postage_Statement_Number', 'Postage_Statement_Number', 'int', 'NULL', nil],
      ['PIC', 'PIC', 'nvarchar(50)', 'NULL', nil],
      ['SKU', 'SKU', 'nvarchar(50)', 'NULL', nil],
      ['column30', 'column30', 'nvarchar(50)', 'NULL', nil],
      ['EFN', 'EFN', 'nvarchar(50)', 'NULL', nil],
      ['Manifest_Package_ID', 'Manifest_Package_ID', 'nvarchar(50)', 'NULL', nil],
      ['Assessment_Type', 'Assessment_Type', 'nvarchar(50)', 'NULL', nil],
      ['Monthly_Adjustment_ID', 'Monthly_Adjustment_ID', 'nvarchar(50)', 'NULL', nil],
      ['Assessment_Details', 'Assessment_Details', 'nvarchar(50)', 'NULL', nil],
      ['Unused_Label_Fee_Amount', 'Unused_Label_Fee_Amount', 'nvarchar(50)', 'NULL', nil],
      ['Mailer_Review_Request_ID', 'Mailer_Review_Request_ID', 'nvarchar(50)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'UspsPostage_Backup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
