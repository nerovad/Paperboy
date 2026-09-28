# frozen_string_literal: true

module Aim
  # The In queue / In pipeline tabs of the profile and BU pages: Ready for
  # Approval, or every other stage filtered by stage, with finished, rejected
  # and deleted invoices left out unless asked for.
  module StageTabs
    extend ActiveSupport::Concern

    PIPELINE_STAGES = (Aim::Invoice::QUEUES.keys - ['ready_for_approval']).freeze
    FINISHED_STAGES = %w[exported rejected deleted].freeze

    included do
      helper_method :pipeline_stages
    end

    private

    def pipeline_stages = PIPELINE_STAGES

    # Sets @tab, @stages and @stage_counts for `scope`, and returns the
    # invoices the chosen tab shows.
    def invoices_for_tab(scope)
      @tab = params[:tab] == 'pipeline' ? 'pipeline' : 'queue'
      @stages = Array(params[:stages]).presence&.intersection(PIPELINE_STAGES) || (PIPELINE_STAGES - FINISHED_STAGES)
      by_state = scope.group(:state).count
      @stage_counts = Aim::Invoice::QUEUES.transform_values { |queue| queue[:states].sum { |state| by_state.fetch(state, 0) } }
      states = @tab == 'queue' ? %w[ready_for_approval] : @stages.flat_map { |stage| Aim::Invoice::QUEUES[stage][:states] }
      scope.where(state: states).newest_first.to_a
    end
  end
end
