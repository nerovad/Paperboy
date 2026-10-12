# frozen_string_literal: true

require 'prawn'
require 'pathname'

# Rebuilds app/reports/billing/tc60/tc60.pdf. Column boxes match tc60.yml and
# stay put so overlay data keeps its coordinates. Header labels follow
# Billing::PdfReportRenderer: Helvetica bold, the same alignment, and a 7pt
# gap above the rule. The grid is tabloid, so size 5 fits there. A letter
# column that is narrower keeps the full word by shrinking that label.

output = Pathname(__dir__).join('../app/reports/billing/tc60/tc60.pdf').expand_path

columns = [
  ['Line#', 8, 15.355469, :center], ['CUNIT', 23.355469, 19.453125, :left],
  ['COBJECT', 42.808594, 22.519531, :left], ['CACTIVITY', 65.328125, 24.570313, :left],
  ['CFUNCTION', 89.898438, 24.570312, :left], ['CPROGRAM', 114.46875, 25.59375, :left],
  ['CPHASE', 140.0625, 20.476562, :left], ['CTASK', 160.539062, 20.472657, :left],
  ['AMOUNT', 181.011719, 24.570312, :right], ['SUNIT', 205.582031, 17.40625, :left],
  ['SOBJECT', 222.988281, 21.496094, :left], ['SACTIVITY', 244.484375, 23.546875, :left],
  ['SFUNCTION', 268.03125, 23.546875, :left], ['SPROGRAM', 291.578125, 24.570313, :left],
  ['SPHASE', 316.148438, 20.472656, :left], ['STASK', 336.621094, 20.476562, :left],
  ['POSTING_REF', 357.097656, 28.664063, :center], ['SERVICE', 385.761719, 20.476562, :center],
  ['DATE', 406.238281, 18.425781, :center], ['DOC_NMBR', 424.664062, 23.546876, :center],
  ['DESCRIPTION', 448.210938, 85.996093, :left], ['OTHER1', 534.207031, 61.421875, :left],
  ['OTHER2', 595.628906, 61.425782, :left], ['OTHER3', 657.054688, 63.472656, :left],
  ['QUANTITY', 720.527344, 25.59375, :right], ['RATE', 746.121094, 18.425781, :right],
  ['COST', 764.546875, 19.453125, :right]
].freeze

table_left = 8
table_right = 784
table_top = 560
header_bottom = 534
table_bottom = 24
row_height = 17
body_rows = 30
header_size = 5
header_baseline = header_bottom + 7

header_font_size = lambda do |pdf, label, width|
  limit = width - 2
  pdf.font('Helvetica', style: :bold, size: header_size)
  text_width = pdf.width_of(label)
  return header_size if text_width <= limit

  header_size * limit / text_width
end

header_x = lambda do |x, width, text_width, alignment|
  case alignment
  when :right then x + width - text_width - 1
  when :center then x + ((width - text_width) / 2.0)
  else x + 1
  end
end

Prawn::Document.generate(output, page_size: [792, 612], margin: 0) do |pdf|
  pdf.fill_color('C8C8C8')
  pdf.fill_rectangle([table_left, table_top], table_right - table_left, table_top - header_bottom)
  pdf.fill_color('000000')
  columns.each do |label, x, width, alignment|
    size = header_font_size.call(pdf, label, width)
    pdf.font('Helvetica', style: :bold, size: size)
    text_width = pdf.width_of(label)
    encoded = pdf.font.normalize_encoding(label)
    pdf.send(:draw_text!, encoded, at: [header_x.call(x, width, text_width, alignment), header_baseline],
                                   kerning: false)
  end

  pdf.stroke_color('000000')
  columns.map { |_label, x, _width, _alignment| x }.push(table_right).each do |x|
    pdf.stroke_line([x, table_bottom], [x, table_top])
  end

  (0..(body_rows + 1)).each do |row|
    offset = if row.zero?
               0
             elsif row == 1
               26
             else
               26 + ((row - 1) * row_height)
             end
    y = table_top - offset
    pdf.stroke_line([table_left, y], [table_right, y])
  end
end

puts "Wrote #{output}"
