# frozen_string_literal: true

module DslSharedSops
  PRINT_2_MAIL = {
    title: 'How to Refresh Print 2 Mail',
    source_system: 'Print 2 Mail',
    reference_group: :source_group,
    reference_title: 'Print 2 Mail Source File',
    reference_path: :source_location,
    instructions: [
      'Open the Print 2 Mail DSL group.',
      'Review the enabled DSLs included in the group.',
      'Click Refresh to update the entire Print 2 Mail group.',
      'Confirm the DataRunner refresh when prompted.'
    ].freeze
  }.freeze
end
