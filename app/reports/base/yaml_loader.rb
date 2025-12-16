# app/reports/base/yaml_loader.rb
module Reports
  module Base
    class YamlLoader
      def initialize(report)
        @path = Rails.root.join("config/reports/#{report}.yml")
      end

      def mapping
        fail "#{@path} not found." unless File.exist?(@path)

        YAML.load_file(@path).fetch("fields")
      end
    end
  end
end
