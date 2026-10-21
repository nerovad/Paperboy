# frozen_string_literal: true

module Aim
  # The stamp designer's data (#221): fields as the browser fills them
  # (stamp_layout.js), and the formats a date field can take.
  module StampLayoutsHelper
    DATE_FORMATS = {
      '' => 'As the field has it', '%m/%d/%Y' => '06/24/2025', '%Y%m%d' => '20250624', '%Y-%m-%d' => '2025-06-24',
      '%b %-d, %Y' => 'Jun 24, 2025', '%m/%d/%Y_%H:%M:%S' => '06/24/2025_12:27:03',
      '%m/%d/%Y %-I:%M %p' => '06/24/2025 12:27 PM'
    }.freeze

    # { field => { kind:, value: } }, dates as written ("2025-06-24",
    # "2025-06-27T12:27:03"), for the live view.
    def stamp_values_data(values)
      values.to_h do |field, value|
        kind = case value
               when ActiveSupport::TimeWithZone, Time, DateTime then 'datetime'
               when Date then 'date'
               when Numeric then 'money'
               else 'text'
               end
        shown = case kind
                when 'datetime' then value.strftime('%Y-%m-%dT%H:%M:%S')
                when 'date' then value.strftime('%Y-%m-%d')
                when 'money' then value.to_f
                else value
                end
        [field, { kind: kind, value: shown }]
      end
    end

    # [[group, [[field, label, kind], ...]], ...] for the chips.
    def stamp_field_groups
      kinds = stamp_values_data(Aim::StampFields.samples)
      Aim::StampFields::FIELDS.group_by { |_, field| field[:group] }.map do |group, fields|
        [group, fields.map { |name, field| [name, field[:label], kinds.dig(name, :kind)] }]
      end
    end

    def stamp_target_name(group) = group&.name || 'Default (groups without their own)'
  end
end
