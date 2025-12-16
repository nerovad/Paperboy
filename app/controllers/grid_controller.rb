class GridController < ApplicationController
  def show
    pdf = GridOverlayPDF.new

    send_data pdf.render,
              filename: "invoice-grid-debug.pdf",
              type: "application/pdf",
              disposition: "inline"
  end
end
