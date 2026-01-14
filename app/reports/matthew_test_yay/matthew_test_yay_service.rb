module MatthewTestYay
  class MatthewTestYayService < Base::ReportService

    # TODO: Stwp in the correct report-specific stored procedure.
    def stored_proc
      "GSABSS.dbo.Paperboy_Reports_Scaffolding"
    end

    def report_name
      "matthew_test_yay"
    end

  end
end
