class MatthewTestReportReportsController < ApplicationController
  def show
    @report_name = "matthew_test_report"
  end

  def run
    MatthewTestReportJob.perform_async(
      sDate: params[:sDate],
      eDate: params[:eDate]
    )

    redirect_to root_path,
      notice: "MatthewTestReport report submitted for generation."
  end
end
