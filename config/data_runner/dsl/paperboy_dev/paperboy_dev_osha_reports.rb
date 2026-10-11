# frozen_string_literal: true

[
  'Paperboy_dev_osha_reports',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'osha_reports',
      local: 'paperboy_dev_osha_reports.csv',
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
      ['approver_id', 'approver_id', 'nvarchar(4000)', 'NULL', nil],
      ['deny_reason', 'deny_reason', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['safety_report_id', 'safety_report_id', 'bigint', 'NULL', nil],
      ['street', 'street', 'nvarchar(4000)', 'NULL', nil],
      ['city', 'city', 'nvarchar(4000)', 'NULL', nil],
      ['state', 'state', 'nvarchar(4000)', 'NULL', nil],
      ['zip', 'zip', 'nvarchar(4000)', 'NULL', nil],
      ['date_of_birth', 'date_of_birth', 'datetime2(6)', 'NULL', nil],
      ['date_hired', 'date_hired', 'datetime2(6)', 'NULL', nil],
      ['sex', 'sex', 'nvarchar(4000)', 'NULL', nil],
      ['name_of_physician_or_other_health_care_professional', 'name_of_physician_or_other_health_care_professional', 'nvarchar(4000)', 'NULL', nil],
      ['was_treatment_given_away_from_the_worksite', 'was_treatment_given_away_from_the_worksite', 'nvarchar(4000)', 'NULL', nil],
      ['facility_name', 'facility_name', 'nvarchar(4000)', 'NULL', nil],
      ['facility_street_address', 'facility_street_address', 'nvarchar(4000)', 'NULL', nil],
      ['facility_city', 'facility_city', 'nvarchar(4000)', 'NULL', nil],
      ['facility_state', 'facility_state', 'nvarchar(4000)', 'NULL', nil],
      ['facility_zip', 'facility_zip', 'nvarchar(4000)', 'NULL', nil],
      ['was_the_employee_treated_in_an_emergency_room', 'was_the_employee_treated_in_an_emergency_room', 'nvarchar(4000)', 'NULL', nil],
      ['was_the_employee_hospitalized_overnight_as_an_inpatient', 'was_the_employee_hospitalized_overnight_as_an_inpatient', 'nvarchar(4000)', 'NULL', nil],
      ['case_number_from_the_log', 'case_number_from_the_log', 'nvarchar(4000)', 'NULL', nil],
      ['date_of_injury_or_illness', 'date_of_injury_or_illness', 'datetime2(6)', 'NULL', nil],
      ['time_employee_began_work', 'time_employee_began_work', 'datetime2(6)', 'NULL', nil],
      ['time_of_event', 'time_of_event', 'datetime2(6)', 'NULL', nil],
      ['what_happened_tell_us_how_the_injury_occurred', 'what_happened_tell_us_how_the_injury_occurred', 'nvarchar(max)', 'NULL', nil],
      ['what_was_the_injury_or_illness', 'what_was_the_injury_or_illness', 'nvarchar(max)', 'NULL', nil],
      ['what_was_the_employee_doing_just_before_the_incident_occurred', 'what_was_the_employee_doing_just_before_the_incident_occurred', 'nvarchar(max)', 'NULL', nil],
      ['what_object_or_substance_directly_harmed_the_employee', 'what_object_or_substance_directly_harmed_the_employee', 'nvarchar(max)', 'NULL', nil],
      ['did_employee_die', 'did_employee_die', 'nvarchar(4000)', 'NULL', nil],
      ['date_of_death', 'date_of_death', 'datetime2(6)', 'NULL', nil],
      ['case_classification', 'case_classification', 'nvarchar(4000)', 'NULL', nil],
      ['case_type', 'case_type', 'nvarchar(4000)', 'NULL', nil],
      ['restricted_duty_days', 'restricted_duty_days', 'int', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['reportable_due_at', 'reportable_due_at', 'datetime2(6)', 'NULL', nil],
      ['reportable_breach_notified_at', 'reportable_breach_notified_at', 'datetime2(6)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'osha_reports',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
