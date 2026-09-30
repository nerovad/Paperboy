# frozen_string_literal: true

# One colouring rule on a Records table: rows whose column meets the condition
# are shaded, e.g. Fleet Vehicles' Last Updated "on or before 12/15/2025" in
# red, labelled "Out of compliance". Rules belong to the table, not a person,
# so everyone who opens it sees the same colours; the table's editors manage
# them from the grid. A table's rules are checked in position order and the
# first that matches colours the row (see RecordsHighlights).
class RecordsHighlightRule < ApplicationRecord
  DATE_OPERATORS = {
    'before' => 'is before',
    'on_or_before' => 'is on or before',
    'after' => 'is after',
    'on_or_after' => 'is on or after',
    'older_than_days' => 'is more than N days ago'
  }.freeze

  TEXT_OPERATORS = {
    'equals' => 'is',
    'contains' => 'contains'
  }.freeze

  ANY_OPERATORS = { 'blank' => 'is blank' }.freeze

  OPERATORS = DATE_OPERATORS.merge(TEXT_OPERATORS, ANY_OPERATORS).freeze

  COLORS = { 'red' => 'Red', 'amber' => 'Amber', 'green' => 'Green', 'blue' => 'Blue' }.freeze

  DATE_KINDS = %i[date datetime].freeze

  # Dates on the grid are read in Pacific time, as the cells show them.
  TIME_ZONE = 'Pacific Time (US & Canada)'

  validates :table_slug, :column_name, presence: true
  validates :operator, inclusion: { in: OPERATORS.keys }
  validates :color, inclusion: { in: COLORS.keys }
  validates :label, length: { maximum: 60 }
  validate :column_must_be_on_the_table
  validate :value_must_suit_the_operator

  scope :for_table, ->(slug) { where(table_slug: slug).order(:position, :id) }

  def self.operators_for(kind)
    DATE_KINDS.include?(kind&.to_sym) ? DATE_OPERATORS.merge(ANY_OPERATORS) : TEXT_OPERATORS.merge(ANY_OPERATORS)
  end

  def table
    RegistryTable.find(table_slug)
  end

  def column
    table&.columns&.find { |c| c.name.to_s == column_name }
  end

  # Whether a cell's raw value meets this rule.
  def matches?(raw)
    return raw.blank? if operator == 'blank'
    return date_matches?(self.class.to_date(raw)) if DATE_OPERATORS.key?(operator)

    text = raw.to_s.downcase
    operator == 'equals' ? text == value.to_s.downcase : text.include?(value.to_s.downcase)
  end

  # "Last Updated is on or before 12/15/2025"
  def description
    phrase = case operator
             when 'blank' then 'is blank'
             when 'older_than_days' then "is more than #{value} days ago"
             when *DATE_OPERATORS.keys then "#{OPERATORS[operator]} #{cutoff&.strftime('%m/%d/%Y')}"
             else %(#{OPERATORS[operator]} "#{value}")
             end
    "#{column&.label || column_name.humanize} #{phrase}"
  end

  def display_label
    label.presence || description
  end

  def self.to_date(raw)
    case raw
    when nil then nil
    when Time, DateTime, ActiveSupport::TimeWithZone then raw.in_time_zone(TIME_ZONE).to_date
    when Date then raw
    else Date.parse(raw.to_s)
    end
  rescue ArgumentError, TypeError
    nil
  end

  private

  def cutoff
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def date_matches?(date)
    return false unless date

    case operator
    when 'before' then date < cutoff
    when 'on_or_before' then date <= cutoff
    when 'after' then date > cutoff
    when 'on_or_after' then date >= cutoff
    when 'older_than_days' then date < Time.current.in_time_zone(TIME_ZONE).to_date - value.to_i
    end
  end

  def column_must_be_on_the_table
    return if table_slug.blank? || column_name.blank?

    if column.nil?
      errors.add(:column_name, 'is not a column on this table')
    elsif !self.class.operators_for(column.kind).key?(operator)
      errors.add(:operator, "doesn't apply to #{column.label}")
    end
  end

  def value_must_suit_the_operator
    case operator
    when 'blank' then self.value = nil
    when 'older_than_days'
      errors.add(:value, 'must be a whole number of days') unless value.to_s.match?(/\A\d+\z/) && value.to_i.positive?
    when *DATE_OPERATORS.keys
      errors.add(:value, 'must be a date') unless cutoff
    else
      errors.add(:value, "can't be blank") if value.blank?
    end
  end
end
