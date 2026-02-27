module MatthewTestReport
  class MatthewTestReportService < Base::ReportService

    # TODO: Replace with the correct report-specific stored procedure.
    # This scaffolding reference (GSABSS.dbo.Paperboy_Reports_Scaffolding) does not exist;
    # update stored_proc to return the real procedure name when available.
    def stored_proc
      "Paperboy_Reports_Scaffolding"
    end

    def report_name
      "matthew_test_report"
    end

  end
end
