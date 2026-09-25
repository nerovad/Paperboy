# frozen_string_literal: true

require 'pathname'

app_root = defined?(Rails) ? Rails.root : Pathname.new(File.expand_path('../../../../', __dir__))
require app_root.join('app/services/p2m/paths').to_s

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
      root_path: P2m::Paths::DATA_RUNNER_ROOT.to_s,
      sent_path: P2m::Paths.configured_location(P2m::Paths::STAGING).to_s,
      output_path: P2m::Paths.configured_location(P2m::Paths::TEMPORARY_OUTPUT).to_s,
      processed_path: P2m::Paths.configured_location(P2m::Paths::PROCESSED).to_s,
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
