class InvoiceJob
  include Sidekiq::Job

  def perform(params)
    rows = Tc60Export.call(
      sDate:      params["sDate"],
      eDate:      params["eDate"],
      type:       params["type"],
      digits:     params["digits"] || 2,
      encumbered: params["encumbered"] || 0
    )

    pdf = InvoiceOverlayPDF.new(rows: rows, params: params)
    # You could save to storage or email it here
  end
end
