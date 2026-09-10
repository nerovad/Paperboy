# frozen_string_literal: true

module Reports
  class TemplateCatalog
    class InvalidFilename < ArgumentError; end
    class MissingTemplate < StandardError; end

    def initialize(root: Rails.root.join('config/reports'))
      @root = Pathname(root).expand_path
    end

    def find(group:, filename:)
      name = safe_filename(filename)
      path = @root.join(group.to_s, name).expand_path
      return path if path.file? && path.to_s.start_with?(template_root(group).to_s + File::SEPARATOR)

      raise MissingTemplate, "Report template not found: #{name}"
    end

    private

    attr_reader :root

    def safe_filename(filename)
      name = File.basename(filename.to_s)
      return name if name == filename.to_s && name.present? && name != '.' && name != '..'

      raise InvalidFilename, 'Report template filename must be a basename'
    end

    def template_root(group)
      root.join(group.to_s).expand_path
    end
  end
end
