# frozen_string_literal: true

[
  'Oms',
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
      name: 'print_2_mail_billing_data'
    },
    orchestration: {
      root_path: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/OMS',
      children: %w[
        Companions
        Dailypresorts
        Moveresults
      ],
      preprocessing: {
        enabled: true,
        args: [:root_path]
      },
      postprocessing: {
        enabled: true,
        args: [:root_path]
      }
    }
  }
]
