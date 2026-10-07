# frozen_string_literal: true

# "This column meets this condition" on a Records table -- Fleet Vehicles'
# Last Updated "is on or before 12/15/2025", say. A highlight rule shades the
# rows that meet it (RecordsHighlightRule); an email rule sends them to someone
# (RecordsEmailRule). Both read a row the same way, so a row that is shaded red
# is a row that gets emailed.
#
# The includer has table_slug, column_name, operator and value columns.
module RecordsCondition
  extend ActiveSupport::Concern

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

  DATE_KINDS = %i[date datetime].freeze

  # Dates on the grid are read in Pacific time, as the cells show them.
  TIME_ZONE = 'Pacific Time (US & Canada)'

  included do
    validates :table_slug, :column_name, presence: true
    validates :operator, inclusion: { in: OPERATORS.keys }
    validate :column_must_be_on_the_table
    validate :value_must_suit_the_operator
  end

  class_methods do
    def operators_for(kind)
      DATE_KINDS.include?(kind&.to_sym) ? DATE_OPERATORS.merge(ANY_OPERATORS) : TEXT_OPERATORS.merge(ANY_OPERATORS)
    end

    def to_date(raw)
      case raw
      when nil then nil
      when Time, DateTime, ActiveSupport::TimeWithZone then raw.in_time_zone(TIME_ZONE).to_date
      when Date then raw
      else Date.parse(raw.to_s)
      end
    rescue ArgumentError, TypeError
      nil
    end
  end

  def table
    RegistryTable.find(table_slug)
  end

  def column
    table&.columns&.find { |c| c.name.to_s == column_name }
  end

  # Whether a cell's raw value meets this condition.
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
