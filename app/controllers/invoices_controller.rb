class InvoicesController < ApplicationController
  # Simple form for staff to enter params
  def new
  end

  # Generate and stream the invoice PDF
  def show
    rows = Tc60Export.call(
      sDate:      params[:sDate],
      eDate:      params[:eDate],
      type:       params[:type],
      digits:     params[:digits].presence || 2,
      encumbered: params[:encumbered].presence || 0
    )

    pdf = InvoiceOverlayPDF.new(
      rows: rows,
      params: params.slice(:sDate, :eDate, :type, :digits, :encumbered)
    )

    filename = [
      "invoice",
      params[:type],
      params[:sDate],
      params[:eDate],
      params[:encumbered].to_s
    ].join("-") + ".pdf"

    send_data pdf.render,
              filename: filename,
              type: "application/pdf",
              disposition: "inline"
  rescue => e
    # You can log and show a friendly error page here
    Rails.logger.error("Invoice generation failed: #{e.message}")
    redirect_to new_invoice_path, alert: "Unable to generate invoice: #{e.message}"
  end
end
