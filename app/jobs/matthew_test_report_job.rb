class MatthewTestReportJob
  include Sidekiq::Job

  def perform(params)
    Reports::MatthewTestReport::MatthewTestReportService
      .new(params.symbolize_keys)
      .call
  end
end
