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
      root_path: '/mnt/o/Outputs/DataRunner',
      sent_path: '00_SentToUSPS',
      output_path: '01_TemporaryOutput',
      processed_path: '02_Processed',
      queue: {
        path: :sent_path,
        pattern: /\AMail\.dat_\d{8,9}\.zip\z/i
      },
      children: %w[
        Companions
        Dailypresorts
        Moveresults
      ],
      preprocessing: {
        enabled: true,
        args: %i[root_path sent_path output_path]
      },
      postprocessing: {
        enabled: true,
        args: %i[root_path sent_path output_path processed_path]
      }
    }
  }
]
