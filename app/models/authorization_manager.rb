# frozen_string_literal: true

# app/models/authorization_manager.rb
#
# Who manages which departments in the parking, badges and keys console. An
# assignment is enough on its own to add, edit and remove that department's
# approvers and to appoint its other managers — no ACL grant is needed, so a
# department can keep its own list without an admin.
#
# A removed assignment stays as a row with removed_at set. The table is its own
# record of who appointed or removed a manager, and when.
class AuthorizationManager < ApplicationRecord
  validates :employee_id, presence: true
  validates :department_id, presence: true
  validates :employee_id, uniqueness: { scope: :department_id, conditions: -> { active },
                                        message: 'already manages this department' }

  scope :active, -> { where(removed_at: nil) }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  # Department ids this employee manages, as strings.
  def self.department_ids_for(employee_id)
    return [] if employee_id.blank?

    active.for_employee(employee_id).pluck(:department_id).map(&:to_s).uniq
  end

  def self.manager?(employee_id)
    employee_id.present? && active.for_employee(employee_id).exists?
  end

  # True when removing this row would leave its department with no manager.
  def last_for_department?
    self.class.active.where(department_id: department_id).where.not(id: id).none?
  end

  def remove!(removed_by:)
    update!(removed_at: Time.current, removed_by: removed_by.to_s)
  end

  def employee
    Employee.find_by(employee_id: employee_id)
  end

  def department
    Coa::Department.find_by(department_id: department_id)
  end
end
