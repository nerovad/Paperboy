# app/reports/base/report_service.rb
module Base
  class ReportService
    attr_reader :params

    def initialize(params = {})
      @params = params.symbolize_keys
    end

    def call
      data     = SqlProvider.new(stored_proc, params).fetch
      mapping  = YamlLoader.new(report_name).mapping
      template = TemplateLoader.new(report_name).path

      PdfRenderer.new(
        template: template,
        mapping:  mapping,
        data:     data,
        report:   report_name
      ).render
    end

    def stored_proc
      raise NotImplementedError, "#{self.class} must implement #stored_proc"
    end

    def report_name
      raise NotImplementedError, "#{self.class} must implement #report_name"
    end

    def validate_params!
      %i[sDate eDate].each do |key|
        raise ArgumentError, "Missing parameter: #{key}" unless params[key]
      end
    end
  end
end
