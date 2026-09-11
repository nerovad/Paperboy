# frozen_string_literal: true

module Reports
  class TemplateCatalog
    class InvalidFilename < ArgumentError; end
    class MissingTemplate < StandardError; end

    def initialize(root: Rails.root.join('app/reports'))
      @root = Pathname(root).expand_path
    end

    def find(family:, report:)
      family_name = safe_filename(family)
      report_name = safe_filename(report)
      path = @root.join(family_name, report_name, "#{report_name}.pdf").expand_path
      return path if path.file? && path.to_s.start_with?(report_root(family_name, report_name).to_s + File::SEPARATOR)

      raise MissingTemplate, "Report template not found: #{family_name}/#{report_name}"
    end

    private

    attr_reader :root

    def safe_filename(filename)
      name = File.basename(filename.to_s)
      return name if name == filename.to_s && name.present? && name != '.' && name != '..'

      raise InvalidFilename, 'Report template filename must be a basename'
    end

    def report_root(family, report)
      root.join(family, report).expand_path
    end
  end
end
