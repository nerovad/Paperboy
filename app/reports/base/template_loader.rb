# app/reports/base/template_loader.rb
module Base
  class TemplateLoader
    def initialize(report)
      @path = Rails.root.join("app/pdfs/#{report}/#{report}.pdf")
    end

    def path
      fail "#{@path} missing." unless File.exist?(@path)
      @path
    end
  end
end
