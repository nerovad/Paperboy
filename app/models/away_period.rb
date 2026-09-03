# frozen_string_literal: true

# Somebody is out, and their work should go to a colleague until they are back.
#
# Two halves to being away, and this model backs both:
#
# * Work that arrives while you are out is redirected as it is routed, so it
#   never lands in your inbox at all — see AwayPeriod.assignee_for, called
#   wherever an assignee is chosen.
# * Work already sitting in your inbox when the period starts is handed over by
#   AwayReassignment, which uses the same reassignment path as the inbox button
#   and so leaves the same history rows behind.
#
# Coming back does not take anything back. A reassigned task stays reassigned,
# matching what the Reassign button already does, and the Take Back button is
# there for the individual ones you want returned.
class AwayPeriod < ApplicationRecord
  # A delegate can themselves be away, so resolution follows the chain. The cap
  # stops a cycle (A covers B, B covers A) from spinning, and is far more hops
  # than any real chain of cover.
  MAX_DELEGATION_HOPS = 5

  validates :employee_id, :delegate_id, :starts_on, :ends_on, presence: true
  validate :delegate_is_not_self
  validate :ends_on_not_before_starts_on
  validate :no_overlapping_period

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
  scope :covering, ->(date) { where(starts_on: ..date).where(ends_on: date..) }
  scope :current, -> { covering(Date.current) }
  scope :chronological, -> { order(:starts_on, :id) }

  # Who should actually receive work aimed at `employee_id`. Returns the id
  # unchanged when nobody is away, so call sites can wrap an assignee without
  # first asking whether there is anything to redirect.
  #
  # Follows a chain of cover, and when that chain loops back on itself stops at
  # the last person reached rather than resolving to nobody — work sitting with
  # a real person beats work sitting with none.
  def self.assignee_for(employee_id, on: Date.current)
    return employee_id if employee_id.blank?

    seen = []
    resolved = employee_id.to_s

    MAX_DELEGATION_HOPS.times do
      seen << resolved
      delegate = covering(on).for_employee(resolved).pick(:delegate_id).to_s
      break if delegate.blank? || seen.include?(delegate)

      resolved = delegate
    end

    resolved
  end

  # The period covering a date for one person, or nil.
  def self.active_for(employee_id, on: Date.current)
    covering(on).for_employee(employee_id).first
  end

  def active?(on = Date.current) = on.between?(starts_on, ends_on)

  def started? = starts_on <= Date.current

  private

  def delegate_is_not_self
    return if delegate_id.blank? || employee_id.blank?

    errors.add(:delegate_id, 'cannot be yourself') if delegate_id.to_s == employee_id.to_s
  end

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, 'cannot be before the start date') if ends_on < starts_on
  end

  # Two overlapping periods would make "who is covering" ambiguous, and
  # assignee_for picks one arbitrarily. Refuse the overlap instead.
  def no_overlapping_period
    return if employee_id.blank? || starts_on.blank? || ends_on.blank?

    clash = AwayPeriod.for_employee(employee_id)
                      .where.not(id: id)
                      .where(starts_on: ..ends_on)
                      .where(ends_on: starts_on..)

    errors.add(:base, 'You already have an away period covering some of those dates') if clash.exists?
  end
end
