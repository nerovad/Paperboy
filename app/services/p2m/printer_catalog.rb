# frozen_string_literal: true

module P2m
  class PrinterCatalog
    QUERY = <<~SQL.squish.freeze
      SELECT DISTINCT printers.printer, printer_queues.queue
      FROM dbo.printers AS printers
      INNER JOIN dbo.printer_queues AS printer_queues
        ON printer_queues.printer = printers.printer
      WHERE printers.printer IS NOT NULL
        AND printer_queues.queue IS NOT NULL
      ORDER BY printers.printer, printer_queues.queue
    SQL

    def call
      GsabssBase.connection.exec_query(QUERY).each_with_object({}) do |row, catalog|
        printer = row.fetch('printer').to_s
        queue = row.fetch('queue').to_s
        catalog[printer] ||= []
        catalog[printer] << queue
      end
    end
  end
end
