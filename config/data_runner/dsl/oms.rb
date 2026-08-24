# frozen_string_literal: true

[
  'Oms',
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
      name: 'print_2_mail_billing_data'
    },
    sop: {
      shared: :p2m_billing,
      reference_title: 'Mail.dat sent to USPS',
      reference_path: :downloaded_file
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
        args: %i[sent_path output_path]
      },
      postprocessing: {
        enabled: true,
        args: %i[sent_path output_path processed_path]
      },
      atomic_inject: true
    }
  }
]
