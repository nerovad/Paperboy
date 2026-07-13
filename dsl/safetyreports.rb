# frozen_string_literal: true

[
  'Safetyreports',
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
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/safetyreports.csv',
      local: 'safetyreports.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id',                                       'id',                                       'bigint',         'IDENTITY(0,0) NOT NULL', nil],
      ['employee_id',                              'employee_id',                              'nvarchar(4000)', 'NULL',                   nil],
      ['name',                                     'name',                                     'nvarchar(4000)', 'NULL',                   nil],
      ['phone',                                    'phone',                                    'nvarchar(4000)', 'NULL',                   nil],
      ['email',                                    'email',                                    'nvarchar(4000)', 'NULL',                   nil],
      ['agency',                                   'agency',                                   'nvarchar(4000)', 'NULL',                   nil],
      ['division',                                 'division',                                 'nvarchar(4000)', 'NULL',                   nil],
      ['department',                               'department',                               'nvarchar(4000)', 'NULL',                   nil],
      ['unit',                                     'unit',                                     'nvarchar(4000)', 'NULL',                   nil],
      ['approver_id',                              'approver_id',                              'nvarchar(4000)', 'NULL',                   nil],
      ['deny_reason',                              'deny_reason',                              'nvarchar(max)',  'NULL',                   nil],
      ['created_at',                               'created_at',                               'datetime2(6)',   'NOT NULL',               nil],
      ['updated_at',                               'updated_at',                               'datetime2(6)',   'NOT NULL',               nil],
      ['report_type',                              'report_type',                              'nvarchar(4000)', 'NULL',                   nil],
      ['bloodborne_pathogen_exposure',             'bloodborne_pathogen_exposure',             'nvarchar(4000)', 'NULL',                   nil],
      ['supervisor_name',                          'supervisor_name',                          'nvarchar(4000)', 'NULL',                   nil],
      ['witness_name',                             'witness_name',                             'nvarchar(4000)', 'NULL',                   nil],
      ['witness_phone',                            'witness_phone',                            'nvarchar(4000)', 'NULL',                   nil],
      ['date_of_injury_or_illness',                'date_of_injury_or_illness',                'datetime2(6)',   'NULL',                   nil],
      ['date_employer_notified',                   'date_employer_notified',                   'datetime2(6)',   'NULL',                   nil],
      ['date_dwc1_given',                          'date_dwc1_given',                          'datetime2(6)',   'NULL',                   nil],
      ['who_gave_the_dwc1',                        'who_gave_the_dwc1',                        'nvarchar(4000)', 'NULL',                   nil],
      ['date_last_worked',                         'date_last_worked',                         'datetime2(6)',   'NULL',                   nil],
      ['date_returned_to_work',                    'date_returned_to_work',                    'datetime2(6)',   'NULL',                   nil],
      ['missed_full_work_day',                     'missed_full_work_day',                     'nvarchar(4000)', 'NULL',                   nil],
      ['still_off_work',                           'still_off_work',                           'nvarchar(4000)', 'NULL',                   nil],
      ['specific_injury_and_body_part_affected',   'specific_injury_and_body_part_affected',   'nvarchar(max)',  'NULL',                   nil],
      ['location_of_incident',                     'location_of_incident',                     'nvarchar(4000)', 'NULL',                   nil],
      ['on_employer_premises',                     'on_employer_premises',                     'nvarchar(4000)', 'NULL',                   nil],
      ['department_where_event_occurred',          'department_where_event_occurred',          'nvarchar(4000)', 'NULL',                   nil],
      ['activity_at_time_of_incident',             'activity_at_time_of_incident',             'nvarchar(max)',  'NULL',                   nil],
      ['how_the_injury_occurred',                  'how_the_injury_occurred',                  'nvarchar(max)',  'NULL',                   nil],
      ['physician_name',                           'physician_name',                           'nvarchar(4000)', 'NULL',                   nil],
      ['physician_address',                        'physician_address',                        'nvarchar(4000)', 'NULL',                   nil],
      ['physician_phone',                          'physician_phone',                          'nvarchar(4000)', 'NULL',                   nil],
      ['hospital_name',                            'hospital_name',                            'nvarchar(4000)', 'NULL',                   nil],
      ['hospital_address',                         'hospital_address',                         'nvarchar(4000)', 'NULL',                   nil],
      ['hospital_phone',                           'hospital_phone',                           'nvarchar(4000)', 'NULL',                   nil],
      ['hospitalized_overnight',                   'hospitalized_overnight',                   'nvarchar(4000)', 'NULL',                   nil],
      ['investigator_name',                        'investigator_name',                        'nvarchar(4000)', 'NULL',                   nil],
      ['investigator_title',                       'investigator_title',                       'nvarchar(4000)', 'NULL',                   nil],
      ['investigator_phone',                       'investigator_phone',                       'nvarchar(4000)', 'NULL',                   nil],
      ['nature_of_incident',                       'nature_of_incident',                       'nvarchar(max)',  'NULL',                   nil],
      ['cause_of_incident',                        'cause_of_incident',                        'nvarchar(max)',  'NULL',                   nil],
      ['root_cause',                               'root_cause',                               'nvarchar(max)',  'NULL',                   nil],
      ['assessment_of_future_severity_potential',  'assessment_of_future_severity_potential',  'nvarchar(max)',  'NULL',                   nil],
      ['assessment_of_probability_of_recurrence',  'assessment_of_probability_of_recurrence',  'nvarchar(max)',  'NULL',                   nil],
      ['unsafe_condition_corrected_immediately',   'unsafe_condition_corrected_immediately',   'nvarchar(4000)', 'NULL',                   nil],
      ['checklistprocedurestraining_modified',     'checklistprocedurestraining_modified',     'nvarchar(4000)', 'NULL',                   nil],
      ['person_responsible_for_corrective_action', 'person_responsible_for_corrective_action', 'nvarchar(4000)', 'NULL',                   nil],
      ['title',                                    'title',                                    'nvarchar(4000)', 'NULL',                   nil],
      ['corrective_department',                    'corrective_department',                    'nvarchar(4000)', 'NULL',                   nil],
      ['corrective_phone',                         'corrective_phone',                         'nvarchar(4000)', 'NULL',                   nil],
      ['targeted_completion_date',                 'targeted_completion_date',                 'datetime2(6)',   'NULL',                   nil],
      ['actual_completion_date',                   'actual_completion_date',                   'datetime2(6)',   'NULL',                   nil],
      ['osha_recordable',                          'osha_recordable',                          'nvarchar(4000)', 'NULL',                   nil],
      ['osha_reportable',                          'osha_reportable',                          'nvarchar(4000)', 'NULL',                   nil],
      ['reportable_injury_codes',                  'reportable_injury_codes',                  'nvarchar(4000)', 'NULL',                   nil],
      ['status',                                   'status',                                   'nvarchar(4000)', 'NOT NULL',               '(N\'in_progress\')']

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'safety_reports',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
