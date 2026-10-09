# frozen_string_literal: true

[
  'Paperboy_dev_critical_information_reportings',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'critical_information_reportings',
      local: 'paperboy_dev_critical_information_reportings.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(4000)', 'NULL', nil],
      ['email', 'email', 'nvarchar(4000)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['division', 'division', 'nvarchar(4000)', 'NULL', nil],
      ['department', 'department', 'nvarchar(4000)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['incident_type', 'incident_type', 'nvarchar(4000)', 'NULL', nil],
      ['incident_details', 'incident_details', 'nvarchar(max)', 'NULL', nil],
      ['cause', 'cause', 'nvarchar(max)', 'NULL', nil],
      ['staff_involved', 'staff_involved', 'nvarchar(max)', 'NULL', nil],
      ['impact_started', 'impact_started', 'datetime2(6)', 'NULL', nil],
      ['location', 'location', 'nvarchar(4000)', 'NULL', nil],
      ['actual_completion_date', 'actual_completion_date', 'datetime2(6)', 'NULL', nil],
      ['urgency', 'urgency', 'nvarchar(4000)', 'NULL', nil],
      ['impact', 'impact', 'nvarchar(4000)', 'NULL', nil],
      ['impacted_customers', 'impacted_customers', 'nvarchar(4000)', 'NULL', nil],
      ['next_steps', 'next_steps', 'nvarchar(max)', 'NULL', nil],
      ['assigned_manager_id', 'assigned_manager_id', 'nvarchar(4000)', 'NULL', nil],
      ['building', 'building', 'nvarchar(4000)', 'NULL', nil],
      ['other_building', 'other_building', 'nvarchar(4000)', 'NULL', nil],
      ['impacted_agency', 'impacted_agency', 'nvarchar(4000)', 'NULL', nil],
      ['impacted_employee', 'impacted_employee', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'critical_information_reportings',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
