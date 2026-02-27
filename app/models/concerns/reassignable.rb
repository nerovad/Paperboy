# app/models/concerns/reassignable.rb

module Reassignable
  extend ActiveSupport::Concern

  included do
    has_many :task_reassignments, as: :task, dependent: :destroy
  end

  # These methods must be implemented by models that include this concern
  def current_assignee_id
    raise NotImplementedError, "#{self.class} must implement #current_assignee_id"
  end

  def assignment_field_name
    raise NotImplementedError, "#{self.class} must implement #assignment_field_name"
  end

  # Reassign this task to a new employee
  def reassign_to!(new_assignee_id:, reassigned_by_id:, reason: nil)
    old_assignee_id = current_assignee_id
    field_name = assignment_field_name

    # Validate new assignee exists
    new_assignee = Employee.find_by(employee_id: new_assignee_id)
    raise ActiveRecord::RecordNotFound, "Employee #{new_assignee_id} not found" unless new_assignee

    # Don't allow reassigning to the same person
    if old_assignee_id.to_s == new_assignee_id.to_s
      raise ArgumentError, "Task is already assigned to this employee"
    end

    transaction do
      # Create history record
      reassignment = task_reassignments.create!(
        from_employee_id: old_assignee_id,
        to_employee_id: new_assignee_id,
        reassigned_by_id: reassigned_by_id,
        reason: reason,
        assignment_field: field_name
      )

      # Update the assignment field
      update_column(field_name, new_assignee_id)

      reassignment
    end
  end

  # Get complete reassignment history in chronological order
  def reassignment_chain
    task_reassignments.order(created_at: :asc).pluck(:from_employee_id, :to_employee_id, :created_at)
  end

  # Check if an employee can "take back" this task
  def can_take_back?(employee_id)
    # Can take back if they appear in the reassignment chain
    # and are not the current assignee
    return false if current_assignee_id.to_s == employee_id.to_s

    task_reassignments.where("from_employee_id = ? OR to_employee_id = ?", employee_id, employee_id).exists?
  end

  # Take back a task (reassign to someone from the history)
  def take_back!(employee_id)
    unless can_take_back?(employee_id)
      raise ArgumentError, "Employee #{employee_id} cannot take back this task"
    end

    reassign_to!(
      new_assignee_id: employee_id,
      reassigned_by_id: employee_id,
      reason: "Task taken back from reassignment chain"
    )
  end

  # Helper: Get all employees who have been involved with this task
  def assignee_history
    ids = task_reassignments.pluck(:from_employee_id, :to_employee_id).flatten.uniq
    ids << current_assignee_id
    ids.compact.uniq
  end
end
