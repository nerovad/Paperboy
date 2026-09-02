# frozen_string_literal: true

# Hands every open task assigned to somebody who is away over to their delegate.
#
# Redirecting only covers work that arrives *after* a period starts; whatever
# was already in the inbox has to be moved. This goes through
# Reassignable#reassign_to! rather than writing the column directly, so each
# handover leaves the same TaskReassignment history row, audit row and
# subscription mail as pressing Reassign in the inbox would — including the
# Take Back button the delegate and the returning owner both rely on.
#
# Safe to run repeatedly: once a task has moved it is no longer assigned to the
# away person, so a second pass finds nothing. The daily job leans on that to
# catch anything a redirect missed.
class AwayReassignment
  Result = Struct.new(:moved, :skipped, keyword_init: true)

  def initialize(period)
    @period = period
  end

  def call
    moved = 0
    skipped = 0

    self.class.reassignable_models.each do |model|
      column = assignment_column_for(model)
      next if column.blank?

      model.where(column => @period.employee_id).find_each do |task|
        next if finished?(task)

        handover(task) ? moved += 1 : skipped += 1
      end
    rescue StandardError => e
      # One unusable model must not strand the rest of somebody's inbox.
      Rails.logger.warn("Away sweep skipped #{model}: #{e.message}")
    end

    Result.new(moved: moved, skipped: skipped)
  end

  # Every model that can hold an assignment. Resolved from the loaded models
  # rather than a hand-kept list, so a new form is covered as soon as it
  # includes the concern.
  def self.reassignable_models
    Rails.application.eager_load! unless Rails.application.config.eager_load

    ApplicationRecord.descendants.select do |model|
      !model.abstract_class? && model.include?(Reassignable)
    end
  end

  private

  def handover(task)
    task.reassign_to!(
      new_assignee_id: @period.delegate_id,
      reassigned_by_id: @period.employee_id,
      reason: "Automatically reassigned — away until #{@period.ends_on.strftime('%b %-d, %Y')}"
    )
    true
  rescue StandardError => e
    Rails.logger.warn("Away sweep could not move #{task.class.name} ##{task.id}: #{e.message}")
    false
  end

  # A finished submission is not work anybody needs to pick up.
  def finished?(task)
    task.respond_to?(:terminal?) && task.terminal?
  end

  # assignment_field_name is per-instance because a model may choose its column
  # from what it has; a blank instance answers it without touching the database.
  def assignment_column_for(model)
    column = model.new.assignment_field_name
    model.column_names.include?(column) ? column : nil
  rescue StandardError
    nil
  end
end
