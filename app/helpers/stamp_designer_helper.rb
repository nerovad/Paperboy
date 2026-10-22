# frozen_string_literal: true

# The shared stamp designer's view pieces (#221, shared since #230): the
# formats a date field can take, the values the browser fills fields with
# (stamp_layout.js), and the designer's toggle-button groups. Used by AIM's
# stamp layouts and the Bates stamp.
module StampDesignerHelper
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

  # A row of buttons setting one of the selected area's settings.
  def stamp_designer_segmented(name, choices, label)
    tag.div(class: 'stamp-designer__segmented', role: 'group', aria: { label: label }) do
      safe_join(choices.map do |value, text|
        tag.button(text, type: 'button', class: 'btn compact',
                         data: { action: 'stamp-designer#choose', key: name, value: value, stamp_designer_target: 'choice' })
      end)
    end
  end
end
