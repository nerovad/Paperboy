# frozen_string_literal: true

class FormEmailRenderer
  # The two placeholders that stand for markup rather than a value: the button
  # {{link}} draws and the table {{changes}} draws. Styled inline, since mail
  # clients ignore stylesheets.
  module Blocks
    BUTTON_STYLE = 'display: inline-block; padding: 10px 20px; background-color: #004976; ' \
                   'color: #ffffff; text-decoration: none; border-radius: 4px;'
    TABLE_STYLE = 'width: 100%; max-width: 640px; border-collapse: collapse; margin: 12px 0;'
    CELL_STYLE = 'padding: 8px 10px; text-align: left; border-bottom: 1px solid #ddd;'
    HEADER_STYLE = "#{CELL_STYLE} background-color: #f5f5f5;".freeze

    module_function

    def link(url, reference)
      return '' if url.blank?

      h.tag.p(h.link_to("Open #{reference}", url, style: BUTTON_STYLE))
    end

    # One row per changed field, what it was and what it is now, with stored
    # ids named the way the edit trail names them.
    def changes(edits, audit)
      return '' if edits.empty?

      header = h.tag.tr(h.safe_join(%w[Field Was Now].map { |label| h.tag.th(label, style: HEADER_STYLE) }))
      rows = edits.map do |edit|
        cells = [edit.column_name.to_s.humanize, audit.call(edit.column_name, edit.old_value),
                 audit.call(edit.column_name, edit.new_value)]
        h.tag.tr(h.safe_join(cells.map { |cell| h.tag.td(cell, style: CELL_STYLE) }))
      end
      h.tag.table(h.safe_join([header, *rows]), style: TABLE_STYLE)
    end

    def h = ApplicationController.helpers
  end
end
