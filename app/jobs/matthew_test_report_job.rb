class MatthewTestReportJob
  include Sidekiq::Job

  def perform(params)
    MatthewTestReport::MatthewTestReportService
      .new(params.symbolize_keys)
      .call
  end
end
