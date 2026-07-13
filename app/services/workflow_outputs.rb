# frozen_string_literal: true

require Rails.root.join('script/constants/workflow_paths')

class WorkflowOutputs
  DIRECTORIES = [
    WorkflowPaths::DOWNLOAD_DIR_NAME,
    WorkflowPaths::NORMALIZED_DIR_NAME,
    WorkflowPaths::SQL_MAP_DIR_NAME,
    WorkflowPaths::SQL_SCHEMA_DIR_NAME,
    WorkflowPaths::APPLIED_DIR_NAME,
    WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME
  ].freeze
  OUTPUT_DIRECTORIES = DIRECTORIES - [WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME]
  EXTENSIONS = %w[.csv .sql .xlsx].freeze

  def initialize(entry, root: Rails.root)
    @entry = entry
    @root = Pathname(root)
  end

  def files
    stems = output_stems
    OUTPUT_DIRECTORIES.flat_map do |directory|
      @root.glob("#{directory}/**/*").select(&:file?).select do |path|
        EXTENSIONS.include?(path.extname.downcase) && stems.include?(path.basename(path.extname).to_s.downcase)
      end
    end.sort
  end

  def backup_files
    stems = output_stems
    backup_root.glob('**/*').select(&:file?).select do |path|
      EXTENSIONS.include?(path.extname.downcase) && backup_for_stems?(path, stems)
    end.sort
  end

  def find!(relative_path)
    path = @root.join(relative_path).cleanpath
    root_prefixes = DIRECTORIES.map { |directory| @root.join(directory).to_s + File::SEPARATOR }
    raise ActiveRecord::RecordNotFound unless root_prefixes.any? { |prefix| path.to_s.start_with?(prefix) }
    raise ActiveRecord::RecordNotFound unless path.file? && (files.include?(path) || backup_files.include?(path))

    path
  end

  def delete_backup_file!(relative_path)
    file = find!(relative_path)
    raise ActiveRecord::RecordNotFound unless backup_files.include?(file)

    file.delete
    file
  end

  def delete_backup_files!
    backup_files.each(&:delete)
  end

  private

  def output_stems
    [@entry.slug, @entry.output_name && File.basename(@entry.output_name, '.*')].compact.map(&:downcase).uniq
  end

  def backup_root
    @root.join(WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME)
  end

  def backup_for_stems?(path, stems)
    basename = path.basename(path.extname).to_s.downcase
    stems.any? { |stem| basename.match?(/\A\d{4}-\d{2}-\d{2}-\d{3}-#{Regexp.escape(stem)}\z/) }
  end
end
