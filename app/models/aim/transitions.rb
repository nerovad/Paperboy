# frozen_string_literal: true

module Aim
  # A state machine declared as a map of allowed moves, { from => [to, ...] },
  # over one column. Shared by Aim::Invoice (state) and Aim::FiscalRecord
  # (status), which name their own move methods and errors but ask the same
  # questions.
  #
  # Every save is checked, not only a move made through the model's own
  # method: a move the map does not allow is refused however it is attempted,
  # including a bare #update. A row being created starts where it is put; one
  # whose current value is not in the map is left to the model's own
  # validations.
  #
  #   include Aim::Transitions
  #   moves_along :state, TRANSITIONS, error: IllegalTransition
  module Transitions
    extend ActiveSupport::Concern

    included do
      class_attribute :transition_column, :transition_map, :transition_error, instance_writer: false
      validate :move_is_allowed, if: -> { persisted? && transition_column && will_save_change_to_attribute?(transition_column) }
    end

    class_methods do
      def moves_along(column, map, error:)
        self.transition_column = column.to_s
        self.transition_map = map
        self.transition_error = error
      end
    end

    def next_states = transition_map.fetch(public_send(transition_column).to_s, [])

    def can_move_to?(new_state) = next_states.include?(new_state.to_s)

    private

    # Raises the model's error, with the model's own wording
    # (#transition_refusal), unless the move is allowed from where it is now.
    def check_move!(new_state)
      raise transition_error, transition_refusal(new_state.to_s) unless can_move_to?(new_state)
    end

    def transition_refusal(new_state)
      "cannot move from #{public_send(transition_column)} to #{new_state}"
    end

    def move_is_allowed
      from, to = attribute_change_to_be_saved(transition_column)
      return if from.blank? || !transition_map.key?(from.to_s) || !transition_map.key?(to.to_s)
      return if transition_map.fetch(from.to_s).include?(to.to_s)

      errors.add(transition_column.to_sym, "cannot move from #{from} to #{to}")
    end
  end
end
