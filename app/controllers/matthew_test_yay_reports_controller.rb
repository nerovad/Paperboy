class MatthewTestYayReportsController < ApplicationController
  def show
    @report_name = "matthew_test_yay"
  end

  def run
    MatthewTestYayJob.perform_async(
      sDate: params[:sDate],
      eDate: params[:eDate]
    )

    redirect_to root_path,
      notice: "MatthewTestYay report submitted for generation."
  end
end
