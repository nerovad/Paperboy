# frozen_string_literal: true

# Who gets told when something happens to a form, for any form in the system.
#
# A visibility grant decides what somebody may *see*; a subscription decides
# what they are *told about*, and the two are deliberately independent — being
# able to open every Critical Information Report is not the same as wanting mail
# about each one. Keyed by model class name like Forms::VisibilityGrant, so it
# covers dynamic form-builder forms and legacy hand-written ones alike, and
# shares that model's "*" all-forms sentinel and form catalog.
#
# Three things a subscription answers:
#
# * +form_type+ — one class name, or ALL_FORMS for every form at once.
# * which events — created / edited / status_changed, independently switchable,
#   so somebody can follow status without drowning in field edits.
# * +delivery_mode+ — 'immediate' mails as each event happens; 'daily_digest'
#   collects a day's worth into one message (FormSubscriptionDigestJob).
#
# Grantee is an employee or a group. Group membership is expanded at send time
# rather than stored, so somebody joining the group starts getting mail without
# the subscription being touched.
module Forms
  class Subscription < ApplicationRecord
    self.table_name = 'form_subscriptions'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormSubscription')

    GRANTEE_TYPES = %w[group employee].freeze

    # Kept in step with Forms::VisibilityGrant rather than redefined, so a form
    # catalog or sentinel change lands in both places at once.
    ALL_FORMS = Forms::VisibilityGrant::ALL_FORMS
    ALL_FORMS_LABEL = Forms::VisibilityGrant::ALL_FORMS_LABEL

    # event name => the column that switches it on.
    EVENT_COLUMNS = {
      'created' => :notify_created,
      'edited' => :notify_edited,
      'status_changed' => :notify_status_changed
    }.freeze
    EVENTS = EVENT_COLUMNS.keys.freeze

    EVENT_LABELS = {
      'created' => 'New submission',
      'edited' => 'Field edited',
      'status_changed' => 'Status changed'
    }.freeze

    DELIVERY_MODE_LABELS = {
      'immediate' => 'Email each change as it happens',
      'daily_digest' => 'One daily digest'
    }.freeze
    DELIVERY_MODES = DELIVERY_MODE_LABELS.keys.freeze

    IMMEDIATE = 'immediate'
    DAILY_DIGEST = 'daily_digest'

    belongs_to :group, foreign_key: :group_id, optional: true

    validates :form_type, presence: true
    validates :grantee_type, inclusion: { in: GRANTEE_TYPES }
    validates :delivery_mode, inclusion: { in: DELIVERY_MODES }
    validates :group_id, presence: true, if: -> { grantee_type == 'group' }
    validates :employee_id, presence: true, if: -> { grantee_type == 'employee' }
    validates :form_type,
              uniqueness: { scope: %i[grantee_type group_id employee_id],
                            message: 'is already subscribed for this recipient' }
    validate :at_least_one_event

    scope :for_group, ->(group_id) { where(grantee_type: 'group', group_id: group_id) }
    scope :for_employee, ->(employee_id) { where(grantee_type: 'employee', employee_id: employee_id.to_s) }
    scope :immediate, -> { where(delivery_mode: IMMEDIATE) }
    scope :daily_digest, -> { where(delivery_mode: DAILY_DIGEST) }
    scope :ordered, -> { order(:form_type, :id) }

    # Subscriptions that cover a form, including any "all forms" row.
    scope :covering, ->(form_type) { where(form_type: [form_type.to_s, ALL_FORMS]) }

    # Subscriptions switched on for one event. Unknown event names match
    # nothing rather than everything.
    scope :for_event, lambda { |event|
      column = EVENT_COLUMNS[event.to_s]
      column ? where(column => true) : none
    }

    def all_forms? = form_type == ALL_FORMS

    def form_label(labels = {})
      return ALL_FORMS_LABEL if all_forms?

      labels[form_type] || form_type.to_s.demodulize.titleize
    end

    # Events this row is switched on for, in EVENTS order.
    def events
      EVENT_COLUMNS.select { |_event, column| self[column] }.keys
    end

    def event_labels = events.map { |event| EVENT_LABELS[event] }

    def delivery_mode_label = DELIVERY_MODE_LABELS[delivery_mode]

    # The employee ids to mail for one event on one form, at one delivery mode.
    # Groups are expanded here so membership changes take effect immediately.
    def self.recipient_ids_for(form_type:, event:, delivery_mode:)
      expand_recipients(covering(form_type).for_event(event).where(delivery_mode: delivery_mode))
    end

    # Every employee id behind a set of subscriptions, groups flattened to their
    # members. One query for the memberships however many group rows there are.
    def self.expand_recipients(subscriptions)
      rows = subscriptions.to_a
      ids = rows.filter_map { |row| row.employee_id.to_s if row.grantee_type == 'employee' }

      group_ids = rows.filter_map { |row| row.group_id if row.grantee_type == 'group' }.uniq
      ids += EmployeeGroup.where(GroupID: group_ids).pluck(:EmployeeID).map(&:to_s) if group_ids.any?

      ids.compact_blank.uniq
    end

    # Every subscription that could mail this employee — their own rows plus the
    # ones held by groups they belong to.
    def self.for_subscriber(employee_id, group_ids = nil)
      group_ids ||= EmployeeGroup.where(EmployeeID: employee_id.to_s).pluck(:GroupID)
      rel = for_employee(employee_id)
      rel = rel.or(where(grantee_type: 'group', group_id: group_ids)) if group_ids.present?
      rel
    end

    # Class names a set of subscriptions covers, with "all forms" expanded.
    def self.covered_form_types(subscriptions)
      Forms::VisibilityGrant.covered_form_types(subscriptions)
    end

    def self.form_type_catalog = Forms::VisibilityGrant.form_type_catalog

    private

    def at_least_one_event
      return if EVENT_COLUMNS.values.any? { |column| self[column] }

      errors.add(:base, 'Pick at least one event to be notified about')
    end
  end
end
