# frozen_string_literal: true

[
  'Doc02user',
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
      name: 'user_entitlements'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/doc02user.csv',
      local: 'doc02user.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['handle',                           'handle',                           'nvarchar(max)', 'NULL', nil],
      ['client_data',                      'client_data',                      'nvarchar(max)', 'NULL', nil],
      ['doccountquota',                    'doccountquota',                    'nvarchar(max)', 'NULL', nil],
      ['keywords',                         'keywords',                         'nvarchar(max)', 'NULL', nil],
      ['rm_instance_handle',               'rm_instance_handle',               'nvarchar(max)', 'NULL', nil],
      ['language',                         'language',                         'nvarchar(max)', 'NULL', nil],
      ['isactive',                         'isactive',                         'nvarchar(max)', 'NULL', nil],
      ['expiration_date',                  'expiration_date',                  'nvarchar(max)', 'NULL', nil],
      ['space',                            'space',                            'nvarchar(max)', 'NULL', nil],
      ['copiedfrom',                       'copiedfrom',                       'nvarchar(max)', 'NULL', nil],
      ['department',                       'department',                       'nvarchar(max)', 'NULL', nil],
      ['password',                         'password',                         'nvarchar(max)', 'NULL', nil],
      ['webdav_title',                     'webdav_title',                     'nvarchar(max)', 'NULL', nil],
      ['javascripton',                     'javascripton',                     'nvarchar(max)', 'NULL', nil],
      ['passwordexpiration',               'passwordexpiration',               'nvarchar(max)', 'NULL', nil],
      ['changepasswordatlogin',            'changepasswordatlogin',            'nvarchar(max)', 'NULL', nil],
      ['modified_date',                    'modified_date',                    'nvarchar(max)', 'NULL', nil],
      ['isrmcontributorenabled',           'isrmcontributorenabled',           'nvarchar(max)', 'NULL', nil],
      ['phone',                            'phone',                            'nvarchar(max)', 'NULL', nil],
      ['routingids',                       'routingids',                       'nvarchar(max)', 'NULL', nil],
      ['contentsizembquota',               'contentsizembquota',               'nvarchar(max)', 'NULL', nil],
      ['layoutdefaults',                   'layoutdefaults',                   'nvarchar(max)', 'NULL', nil],
      ['domain',                           'domain',                           'nvarchar(max)', 'NULL', nil],
      ['attachmentasurl',                  'attachmentasurl',                  'nvarchar(max)', 'NULL', nil],
      ['routing_template_id',              'routing_template_id',              'nvarchar(max)', 'NULL', nil],
      ['lastsynchronized',                 'lastsynchronized',                 'nvarchar(max)', 'NULL', nil],
      ['pagingincrement',                  'pagingincrement',                  'nvarchar(max)', 'NULL', nil],
      ['failedlogincount',                 'failedlogincount',                 'nvarchar(max)', 'NULL', nil],
      ['mailstop',                         'mailstop',                         'nvarchar(max)', 'NULL', nil],
      ['description',                      'description',                      'nvarchar(max)', 'NULL', nil],
      ['candeclareifcontributor',          'candeclareifcontributor',          'nvarchar(max)', 'NULL', nil],
      ['locale',                           'locale',                           'nvarchar(max)', 'NULL', nil],
      ['title',                            'title',                            'nvarchar(max)', 'NULL', nil],
      ['email_format',                     'email_format',                     'nvarchar(max)', 'NULL', nil],
      ['home_page',                        'home_page',                        'nvarchar(max)', 'NULL', nil],
      ['userlevel',                        'userlevel',                        'nvarchar(max)', 'NULL', nil],
      ['isinteractenabled',                'isinteractenabled',                'nvarchar(max)', 'NULL', nil],
      ['noemailagentnotifyfor',            'noemailagentnotifyfor',            'nvarchar(max)', 'NULL', nil],
      ['first_name',                       'first_name',                       'nvarchar(max)', 'NULL', nil],
      ['isrmadminenabled',                 'isrmadminenabled',                 'nvarchar(max)', 'NULL', nil],
      ['email',                            'email',                            'nvarchar(max)', 'NULL', nil],
      ['summary',                          'summary',                          'nvarchar(max)', 'NULL', nil],
      ['alternateemail',                   'alternateemail',                   'nvarchar(max)', 'NULL', nil],
      ['readyfordeclare',                  'readyfordeclare',                  'nvarchar(max)', 'NULL', nil],
      ['agency',                           'agency',                           'nvarchar(max)', 'NULL', nil],
      ['routing_choice',                   'routing_choice',                   'nvarchar(max)', 'NULL', nil],
      ['isrecord',                         'isrecord',                         'nvarchar(max)', 'NULL', nil],
      ['last_name',                        'last_name',                        'nvarchar(max)', 'NULL', nil],
      ['nosubscriptionnotifyfor',          'nosubscriptionnotifyfor',          'nvarchar(max)', 'NULL', nil],
      ['orgnumber',                        'orgnumber',                        'nvarchar(max)', 'NULL', nil],
      ['remote_dn',                        'remote_dn',                        'nvarchar(max)', 'NULL', nil],
      ['homespace',                        'homespace',                        'nvarchar(max)', 'NULL', nil],
      ['isrmcoordinatorenabled',           'isrmcoordinatorenabled',           'nvarchar(max)', 'NULL', nil],
      ['last_whats_new',                   'last_whats_new',                   'nvarchar(max)', 'NULL', nil],
      ['userichtextedit',                  'userichtextedit',                  'nvarchar(max)', 'NULL', nil],
      ['charactercode',                    'charactercode',                    'nvarchar(max)', 'NULL', nil],
      ['username',                         'username',                         'nvarchar(max)', 'NULL', nil],
      ['destination_subscription',         'destination_subscription',         'nvarchar(max)', 'NULL', nil],
      ['destination_owner',                'destination_owner',                'nvarchar(max)', 'NULL', nil],
      ['destination_modifiedby',           'destination_modifiedby',           'nvarchar(max)', 'NULL', nil],
      ['destination_favorite',             'destination_favorite',             'nvarchar(max)', 'NULL', nil],
      ['destination_associatedcollection', 'destination_associatedcollection', 'nvarchar(max)', 'NULL', nil],
      ['source_membership',                'source_membership',                'nvarchar(max)', 'NULL', nil],
      ['source_subscriber',                'source_subscriber',                'nvarchar(max)', 'NULL', nil],
      ['source_owner',                     'source_owner',                     'nvarchar(max)', 'NULL', nil],
      ['source_modifiedby',                'source_modifiedby',                'nvarchar(max)', 'NULL', nil],
      ['source_lockedby',                  'source_lockedby',                  'nvarchar(max)', 'NULL', nil],
      ['source_favorite',                  'source_favorite',                  'nvarchar(max)', 'NULL', nil],
      ['last_login',                       'last_login',                       'nvarchar(max)', 'NULL', nil],
      ['create_date',                      'create_date',                      'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'doc02user',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
