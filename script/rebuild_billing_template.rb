# frozen_string_literal: true

require 'prawn'
require 'pathname'

output = Pathname(__dir__).join('../config/reports/billing/template.pdf').expand_path

columns = [
  ['Line#', 8, 15.355469], ['CUNIT', 23.355469, 19.453125],
  ['COBJECT', 42.808594, 22.519531], ['CACTIVITY', 65.328125, 24.570313],
  ['CFUNCTION', 89.898438, 24.570312], ['CPROGRAM', 114.46875, 25.59375],
  ['CPHASE', 140.0625, 20.476562], ['CTASK', 160.539062, 20.472657],
  ['AMOUNT', 181.011719, 24.570312], ['SUNIT', 205.582031, 17.40625],
  ['SOBJECT', 222.988281, 21.496094], ['SACTIVITY', 244.484375, 23.546875],
  ['SFUNCTION', 268.03125, 23.546875], ['SPROGRAM', 291.578125, 24.570313],
  ['SPHASE', 316.148438, 20.472656], ['STASK', 336.621094, 20.476562],
  ['POSTING_REF', 357.097656, 28.664063], ['SERVICE', 385.761719, 20.476562],
  ['DATE', 406.238281, 18.425781], ['DOC_NMBR', 424.664062, 23.546876],
  ['DESCRIPTION', 448.210938, 85.996093], ['OTHER1', 534.207031, 61.421875],
  ['OTHER2', 595.628906, 61.425782], ['OTHER3', 657.054688, 63.472656],
  ['QUANTITY', 720.527344, 25.59375], ['RATE', 746.121094, 18.425781],
  ['COST', 764.546875, 19.453125]
].freeze

table_left = 8
table_right = 784
table_top = 560
header_bottom = 534
table_bottom = 24
row_height = 17
body_rows = 30

Prawn::Document.generate(output, page_size: [792, 612], margin: 0) do |pdf|
  pdf.fill_color('C8C8C8')
  pdf.fill_rectangle([table_left, table_top], table_right - table_left, table_top - header_bottom)
  pdf.fill_color('000000')
  pdf.font('Helvetica', style: :bold, size: 4) do
    columns.each do |label, x, width|
      options = {
        at: [x + 1, table_top - 3], width: width - 2, height: 22,
        align: :center, valign: :center, overflow: :truncate,
        disable_wrap: true
      }
      pdf.text_box(label, **options)
    end
  end

  pdf.stroke_color('000000')
  columns.map { |_label, x, _width| x }.push(table_right).each do |x|
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
