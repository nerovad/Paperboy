# frozen_string_literal: true

# A standing email about the rows of a Records table that meet a condition:
# "every Monday at 07:00, tell each agency's contacts which of its vehicles
# were last updated on or before 12/15/2025". The condition is the one a
# highlight rule uses (RecordsCondition); the timing is RecurringSchedule.
#
# A rule sends either to the same people every time (recipients) or, when it
# has a split_column, to each value's contacts with only that value's rows
# (RecordsEmailContact). Rows nobody is listed for go to the rule's owner, so a
# vehicle is never dropped for want of a contact. A run that matches no rows
# sends nothing: the emails stop once everything is back in compliance.
#
# Rules belong to the table and are managed by its editors from the grid's
# Email dialog. The owner (employee_id) is whoever created the rule; their edit
# grant is re-checked on every run (see RecordsEmailRuleJob).
class RecordsEmailRule < ApplicationRecord
  include RecordsCondition
  include RecurringSchedule

  # One email of a run: the rows, who gets them, the split value they share
  # (nil for a rule that does not split) and, for the owner's catch-all, the
  # values nobody is listed for.
  Batch = Struct.new(:to, :rows, :group, :unrouted, keyword_init: true)

  has_many :deliveries, class_name: 'RecordsEmailDelivery', dependent: :nullify, inverse_of: :rule

  validates :label, presence: true, length: { maximum: 60 }
  validates :message, presence: true, length: { maximum: 1000 }
  validate :split_column_must_be_on_the_table
  validate :recipients_must_be_county_employees
  validate :someone_must_be_named

  scope :for_table, ->(slug) { where(table_slug: slug).order(:created_at, :id) }

  before_create :schedule_first_run

  def recipient_list = RecordsEmailRecipients.parse(recipients)

  def split? = split_column.present?

  def split_column_label
    table&.columns&.find { |c| c.name.to_s == split_column }&.label || split_column.to_s.humanize
  end

  # "Each Agency's contacts" or the addresses themselves.
  def recipients_description
    split? ? "Each #{split_column_label}'s contacts" : recipient_list.join(', ')
  end

  def schedule_description = timing_description

  # The table's rows that meet the condition today. Only a declared registry
  # column is read, so a rule can never call an arbitrary method on a row.
  def matching_rows
    return [] unless table && column

    table.scope.to_a.select { |row| matches?(row.public_send(column_name)) }
  end

  # Who gets which of +rows+. Addresses that no longer belong to an employee
  # are dropped here, at send time; whatever that leaves without a recipient
  # goes to +owner_email+ in one catch-all batch.
  def batches(rows, owner_email:)
    routed, orphaned = split? ? split_batches(rows) : fixed_batches(rows)
    return routed if orphaned.empty? || owner_email.blank?

    routed + [Batch.new(to: [owner_email], rows: orphaned.flat_map(&:rows), unrouted: orphaned.map(&:group))]
  end

  def execute!
    RecordsEmailRuleJob.perform_later(id)

    update(last_run_at: Time.current)
    update_next_run!
  end

  private

  def fixed_batches(rows)
    batch = Batch.new(to: RecordsEmailRecipients.county(recipient_list), rows: rows)
    batch.to.any? ? [[batch], []] : [[], [batch]]
  end

  def split_batches(rows)
    directory = RecordsEmailContact.directory(table_slug, split_column)

    batches = rows.group_by { |row| RecordsEmailContact.key(row.public_send(split_column)) }.map do |key, group_rows|
      to = RecordsEmailRecipients.county(directory.fetch(key, []))
      Batch.new(to: to, rows: group_rows, group: group_rows.first.public_send(split_column).to_s.strip.presence || '(blank)')
    end

    batches.partition { |batch| batch.to.any? }
  end

  def split_column_must_be_on_the_table
    return if split_column.blank? || table.nil?

    errors.add(:split_column, 'is not a column on this table') if table.columns.none? { |c| c.name.to_s == split_column }
  end

  def recipients_must_be_county_employees
    outsiders = RecordsEmailRecipients.outsiders(recipient_list)
    return if outsiders.empty?

    errors.add(:recipients, "must be county employees (not #{outsiders.join(', ')})")
  end

  def someone_must_be_named
    errors.add(:recipients, "can't be blank unless the rule splits by a column") if !split? && recipient_list.empty?
  end

  def schedule_first_run
    self.next_run_at ||= calculate_next_run
  end
end
