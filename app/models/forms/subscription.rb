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
# * which events — created / edited / status_changed / comment_added,
#   independently switchable, so somebody can follow status without drowning
#   in field edits.
# * +delivery_mode+ — 'immediate' mails as each event happens; 'daily_digest'
#   collects a day's worth into one message (FormSubscriptionDigestJob).
#
# Grantee is an employee or a group. Group membership is expanded at send time
# rather than stored, so somebody joining the group starts getting mail without
# the subscription being touched.
#
# A member can opt out of a group subscription from their own Settings
# (Forms::SubscriptionOptOut) without leaving the group, unless the admin marked
# it +required+. Personal rows are never required: their owner removes them.
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
      'status_changed' => :notify_status_changed,
      'comment_added' => :notify_comment_added
    }.freeze
    EVENTS = EVENT_COLUMNS.keys.freeze

    EVENT_LABELS = {
      'created' => 'New submission',
      'edited' => 'Field edited',
      'status_changed' => 'Status changed',
      'comment_added' => 'Comment added'
    }.freeze

    DELIVERY_MODE_LABELS = {
      'immediate' => 'Email each change as it happens',
      'daily_digest' => 'One daily digest'
    }.freeze
    DELIVERY_MODES = DELIVERY_MODE_LABELS.keys.freeze

    IMMEDIATE = 'immediate'
    DAILY_DIGEST = 'daily_digest'

    belongs_to :group, foreign_key: :group_id, optional: true
    has_many :opt_outs, class_name: 'Forms::SubscriptionOptOut', foreign_key: :form_subscription_id,
                        inverse_of: :subscription, dependent: :delete_all

    before_validation { self.required = false unless grantee_type == 'group' }

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

    def group? = grantee_type == 'group'

    # Whether a member may stop this subscription mailing them.
    def opt_out_allowed? = group? && !required?

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
    # members less whoever opted out of that row. One query for the memberships
    # and one for the opt-outs however many group rows there are. Somebody who
    # opted out of a group row but also subscribes personally is still mailed.
    def self.expand_recipients(subscriptions)
      rows = subscriptions.to_a
      ids = rows.filter_map { |row| row.employee_id.to_s unless row.group? }
      group_rows = rows.select(&:group?)

      (ids + opted_in_member_ids(group_rows)).compact_blank.uniq
    end

    def self.opted_in_member_ids(group_rows)
      return [] if group_rows.empty?

      members = EmployeeGroup.where(GroupID: group_rows.map(&:group_id).uniq)
                             .pluck(:GroupID, :EmployeeID)
                             .group_by(&:first)
                             .transform_values { |pairs| pairs.map { |_group, employee| employee.to_s } }
      opted_out = SubscriptionOptOut.employee_ids_by_subscription(group_rows.select(&:opt_out_allowed?).map(&:id))

      group_rows.flat_map { |row| members.fetch(row.group_id, []) - opted_out.fetch(row.id, []) }
    end
    private_class_method :opted_in_member_ids

    # Group subscriptions reaching this employee through groups they belong to,
    # whether or not they have opted out of them.
    def self.reaching_member(employee_id, group_ids = nil)
      group_ids ||= EmployeeGroup.where(EmployeeID: employee_id.to_s).pluck(:GroupID)
      where(grantee_type: 'group', group_id: group_ids)
    end

    # Every subscription that mails this employee — their own rows plus the
    # ones held by groups they belong to, less the group rows they opted out of.
    def self.for_subscriber(employee_id, group_ids = nil)
      group_ids ||= EmployeeGroup.where(EmployeeID: employee_id.to_s).pluck(:GroupID)
      employee_scope = for_employee(employee_id)
      return employee_scope if group_ids.blank?

      opted_out = SubscriptionOptOut.where(employee_id: employee_id.to_s).select(:form_subscription_id)
      group_scope = reaching_member(employee_id, group_ids)
      employee_scope.or(group_scope.where(required: true)).or(group_scope.where.not(id: opted_out))
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
