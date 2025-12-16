require 'prawn'
require 'prawn/templates'

class GridOverlayPDF < Prawn::Document
  # {{{ Initialzie InvoiceOverlayPDF

  def initialize
    super(
      template: Rails.root.join("app/pdfs/templates/InvoiceBackground.pdf"),
      margin: 0
    )

    font "Helvetica"
    stroke_color "CCCCCC"

    draw_grid
    draw_labels
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Draw grid lines (every 20 points = ~0.28 inches) Adjust spacing to your
  # preference.

  def draw_grid(step = 20)
    (0..bounds.width.to_i).step(step) do |x|
      stroke_line [x, 0], [x, bounds.height]
    end

    (0..bounds.height.to_i).step(step) do |y|
      stroke_line [0, y], [bounds.width, y]
    end
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Label coordinates at intersections

  def draw_labels(step = 40)
    fill_color "444444"
    size = 6

    (0..bounds.width.to_i).step(step) do |x|
      draw_text x.to_s, size: size, at: [x + 2, 10]
    end

    (0..bounds.height.to_i).step(step) do |y|
      draw_text y.to_s, size: size, at: [2, y + 2]
    end
  end

  # ------------------------------------------------------------------------ }}}
end
