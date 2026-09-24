# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/constants/workflow_paths')
require_relative '../../lib/paperboy/file_store'

class WorkflowOutputs
  class RemoteFile
    attr_reader :store, :name, :relative_path, :metadata

    def initialize(store:, name:, relative_path:, metadata:)
      @store = store
      @name = name
      @relative_path = relative_path
      @metadata = metadata
    end

    def basename
      Pathname.new(name).basename
    end

    def file?
      true
    end

    def size
      metadata[:size]
    end

    def mtime
      metadata[:modified_at]
    end

    def local_path
      @local_path ||= store.download(name)
    end

    def cleanup
      store.cleanup_download(@local_path)
      @local_path = nil
    end

    def delete
      store.remove(name)
    end
  end

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

  def initialize(entry, root: WorkflowPaths::OUTPUT_ROOT, inbox_root: WorkflowPaths::INBOX_DIR)
    @entry = entry
    @root = Pathname(root)
    @inbox_root = Pathname(inbox_root)
  end

  def files
    stems = output_stems
    return remote_files(stems) if shortcut_root?

    output_roots = [@root, @inbox_root]
    output_roots.flat_map do |root|
      directories = root == @root ? OUTPUT_DIRECTORIES : ['.']
      directories.flat_map { |directory| root.glob("#{directory}/**/*") }.select(&:file?).select do |path|
        EXTENSIONS.include?(path.extname.downcase) && stems.include?(path.basename(path.extname).to_s.downcase)
      end
    end.sort
  end

  def backup_files
    stems = output_stems
    return remote_files(stems, prefix: WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME) if shortcut_root?

    backup_root.glob('**/*').select(&:file?).select do |path|
      EXTENSIONS.include?(path.extname.downcase) && backup_for_stems?(path, stems)
    end.sort
  end

  def find!(relative_path)
    return find_remote!(relative_path) if shortcut_root?

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

  def shortcut_root?
    @root.extname.casecmp?('.lnk')
  end

  def remote_files(stems, prefix: nil)
    store = Paperboy::FileStore.for(@root)
    store.walk(prefix).filter_map do |metadata|
      name = metadata.fetch(:name)
      next unless output_file?(name, stems, prefix: prefix)

      RemoteFile.new(store: store, name: name, relative_path: name, metadata: metadata)
    end.sort_by(&:relative_path)
  end

  def output_file?(name, stems, prefix: nil)
    path = Pathname.new(name)
    return false unless EXTENSIONS.include?(path.extname.downcase)

    basename = path.basename(path.extname).to_s.downcase
    prefix == WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME ? backup_for_stems?(path, stems) : stems.include?(basename)
  end

  def find_remote!(relative_path)
    path = Pathname.new(relative_path.to_s).cleanpath
    raise ActiveRecord::RecordNotFound unless path.to_s == relative_path.to_s
    raise ActiveRecord::RecordNotFound unless DIRECTORIES.any? { |directory| path.each_filename.first == directory }

    (files + backup_files).find { |file| file.relative_path == path.to_s } || raise(ActiveRecord::RecordNotFound)
  end

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
