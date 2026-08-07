# frozen_string_literal: true

module Dam
  # One custom-metadata criterion from the Advanced Search modal, normalised
  # against the field registry and able to turn itself into a set of asset ids.
  #
  # Split out of Dam::AssetSearch because this is where the type-dependent work
  # lives — a "between" on a number and a "between" on a date compare different
  # columns, and each operator needs its own clause.
  class MetadataFilter
    # Operators that compare against nothing, so a blank value is legal.
    VALUELESS = %w[present blank].freeze

    attr_reader :field, :operator, :value, :value_to

    # Builds filters from the modal's `meta` param, dropping rows that name no
    # known field and rows left blank. `fields` is a key => Dam::MetadataField
    # hash; anything outside it is discarded, so a request cannot introduce a
    # field or an operator of its own.
    def self.from_params(rows, fields)
      rows = rows.is_a?(Hash) ? rows.values : Array(rows)
      rows.filter_map do |row|
        row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
        row = (row || {}).with_indifferent_access
        field = fields[row[:field].to_s]
        next if field.nil?

        filter = new(field: field, operator: row[:operator], value: row[:value], value_to: row[:value_to])
        filter.usable? ? filter : nil
      end
    end

    def initialize(field:, operator:, value:, value_to: nil)
      @field = field
      # An operator the field does not define falls back to its first, rather
      # than being passed through to the case in #asset_ids.
      @operator = field.operators.include?(operator) ? operator : field.operators.first
      @value = value.to_s.strip
      @value_to = value_to.to_s.strip
    end

    def key = field.key

    def label = field.label

    def usable? = value.present? || VALUELESS.include?(operator)

    # A relation of asset ids this filter admits, or nil when the value cannot
    # be interpreted (a "greater than" against the word "blue"), in which case
    # the caller ignores the filter rather than returning nothing.
    def asset_ids
      rows = Dam::MetadataValue.where(field_key: key).select(:asset_id)

      case operator
      when 'contains' then rows.where('value LIKE ?', "%#{like(value)}%")
      when 'starts_with' then rows.where('value LIKE ?', "#{like(value)}%")
      when 'equals' then rows.where(value: value)
      when 'present' then rows.where.not(value: [nil, ''])
      when 'not_contains' then complement(rows.where('value LIKE ?', "%#{like(value)}%"))
      when 'not_equals' then complement(rows.where(value: value))
      when 'blank' then complement(rows.where.not(value: [nil, '']))
      when 'greater_than' then numeric(rows) { |number| { numeric_value: (number..) } }
      when 'less_than' then numeric(rows) { |number| { numeric_value: (..number) } }
      when 'after' then dated(rows) { |time| { date_value: (time..) } }
      when 'before' then dated(rows) { |time| { date_value: (..time) } }
      when 'on' then dated(rows) { |time| { date_value: time.beginning_of_day..time.end_of_day } }
      when 'between' then between(rows)
      end
    end

    def chip
      return "#{label} #{operator.tr('_', ' ')}" if VALUELESS.include?(operator)
      return "#{label} between #{value} and #{value_to}" if operator == 'between'

      "#{label} #{operator.tr('_', ' ')} #{value}"
    end

    def to_h
      { field: key, label: label, operator: operator, value: value, value_to: value_to }
    end

    private

    # "Not" operators exclude every asset that has a matching value, which is
    # not the same as the assets whose value does not match: an asset with the
    # field unset must still count as "not equal to red".
    def complement(matching)
      Dam::Asset.where.not(id: matching).select(:id)
    end

    def numeric(rows)
      number = Float(value, exception: false)
      number && rows.where(yield(number))
    end

    def dated(rows)
      time = parse_time(value)
      time && rows.where(yield(time))
    end

    # Numbers win over dates when both parse, so "3 to 5" is a range rather
    # than two failed date guesses.
    def between(rows)
      low = Float(value, exception: false)
      high = Float(value_to, exception: false)
      return rows.where(numeric_value: low..high) if low && high

      from = parse_time(value)
      to = parse_time(value_to)
      return nil unless from && to

      rows.where(date_value: from.beginning_of_day..to.end_of_day)
    end

    def parse_time(raw)
      return nil if raw.blank?

      Time.zone.parse(raw)
    rescue ArgumentError
      nil
    end

    # LIKE wildcards a user typed are literals, not operators — searching for
    # "50%" should not match everything.
    def like(raw)
      ActiveRecord::Base.sanitize_sql_like(raw.to_s)
    end
  end
end
