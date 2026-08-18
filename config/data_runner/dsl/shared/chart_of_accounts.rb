# frozen_string_literal: true

module DslSharedSops
  CHART_OF_ACCOUNTS = {
    title: 'How to Refresh the Chart of Accounts',
    source_system: 'Auditor-Controller Office',
    reference_group: :source_group,
    reference_title: 'Downloaded Chart of Accounts File',
    reference_path: :downloaded_file,
    instructions: [
      'Open the Chart of Accounts DSL group.',
      'Review the enabled DSLs included in the group.',
      'Click Refresh to update the entire Chart of Accounts.',
      'Confirm the DataRunner refresh when prompted.'
    ].freeze
  }.freeze
end
