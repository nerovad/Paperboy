# frozen_string_literal: true

module Paperboy
  module Pdf
    # Stamp areas as saved -- { 'name', 'rows', and StampBox's settings } --
    # filled with +values+ (Paperboy::Pdf::StampTemplate) and turned into
    # StampBoxes: rows whose fields are all empty are left out, and an area
    # left with no rows is dropped. Shared by AIM's approval stamp and the
    # Bates stamp.
    module StampAreas
      module_function

      def boxes(areas, values, formats: {})
        template = StampTemplate.new(values, formats: formats)
        Array(areas).filter_map do |area|
          lines = template.lines(Array(area['rows']))
          StampBox.build(area.except('name', 'rows').merge('lines' => lines)) if lines.any?
        end
      end
    end
  end
end
