# frozen_string_literal: true

require File.expand_path('../../../../app/services/p2m/paths', __dir__)

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
      sent_path: P2m::Paths::STAGING,
      output_path: P2m::Paths::TEMPORARY_OUTPUT,
      processed_path: P2m::Paths::PROCESSED,
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
