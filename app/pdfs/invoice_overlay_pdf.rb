require "prawn"
require "prawn/templates"

class InvoiceOverlayPDF < Prawn::Document
  # {{{ Initialzie InvoiceOverlayPDF

  def initialize(rows:, params:)
    @rows   = rows
    @params = params.symbolize_keys
    @coords = INVOICE_COORDS[:invoice]

    super(
      template: Rails.root.join("app/pdfs/templates/InvoiceBackground.pdf"),
      margin: 0
    )

    font "Helvetica"

    draw_header
    draw_summary
    draw_line_items

    number_pages "Page <page> of <total>",
                 at: [ bounds.right - 50, 20 ],
                 size: 8
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Header: date range, type, encumbered flag

  def draw_header
    h = @coords[:header]

    date_range_text = "#{@params[:sDate]} – #{@params[:eDate]}"
    draw_text date_range_text,
              at: [ h[:date_range][:x], h[:date_range][:y] ],
              size: 10

    draw_text "Type: #{@params[:type]}",
              at: [ h[:billing_type][:x], h[:billing_type][:y] ],
              size: 10

    enc_text = @params[:encumbered].to_i == 1 ? "Encumbered" : "Non-Encumbered"
    draw_text enc_text,
              at: [ h[:encumbered_flag][:x], h[:encumbered_flag][:y] ],
              size: 10
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Summary totals calculated from rows

  def draw_summary
    s = @coords[:summary]
    totals = summarize(@rows)

    draw_text currency(totals[:total_amount]),
              at: [ s[:total_amount][:x], s[:total_amount][:y] ],
              size: 10

    draw_text currency(totals[:total_cost]),
              at: [ s[:total_cost][:x], s[:total_cost][:y] ],
              size: 10

    draw_text totals[:total_quantity].to_s,
              at: [ s[:total_quantity][:x], s[:total_quantity][:y] ],
              size: 10
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Line item table

  def draw_line_items
    li = @coords[:line_items]

    move_cursor_to li[:y]

    table(line_item_table_data,
          header: true,
          cell_style: { size: 8 }) do
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
      columns(3..5).align = :right
      self.width = li[:width]
      self.position = li[:x]
    end
  end

  # ------------------------------------------------------------------------ }}}
  # {{{ Line item table data

  def line_item_table_data
    rows = [
      [ "Date", "Description", "Doc #", "Qty", "Rate", "Amount" ]
    ]

    @rows.each do |row|
      rows << [
        row["DATE"].to_date.strftime("%m/%d/%Y"),
        row["DESCRIPTION"],
        row["DOC_NMBR"],
        row["QUANTITY"],
        currency(row["RATE"]),
        currency(row["AMOUNT"])
      ]
    end

    rows
  end

  # ---------------------------------------------------------------------------
  # {{{ Helpers

  private

  def summarize(rows)
    {
      total_amount:   rows.sum { |r| r["AMOUNT"].to_f },
      total_cost:     rows.sum { |r| r["COST"].to_f },
      total_quantity: rows.sum { |r| r["QUANTITY"].to_f }
    }
  end

  def currency(value)
    format("$%.2f", value.to_f)
  end
  # ---------------------------------------------------------------------------
end
