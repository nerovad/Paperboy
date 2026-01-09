class GridController < ApplicationController
  def show
    pdf = GridOverlayPdf.new

    send_data pdf.render,
              filename: "invoice-grid-debug.pdf",
              type: "application/pdf",
              disposition: "inline"
  end
end
