# frozen_string_literal: true

require 'pathname'
require 'tempfile'
require 'tmpdir'
require_relative '../../../../lib/paperboy/file_store'
require_relative '../constants/workflow_paths'

# File-store operations shared by the DataRunner download stage.
class DataRunnerDownloadStore
  def initialize(root: WorkflowPaths::OUTPUT_ROOT)
    root = Pathname(root)
    @shortcut_backed = root.extname.casecmp?('.lnk')
    if @shortcut_backed
      @download_store = Paperboy::FileStore.for(root)
      @backup_store = @download_store
      @download_prefix = WorkflowPaths::DOWNLOAD_DIR_NAME
      @backup_prefix = WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME
    else
      @download_store = Paperboy::FileStore.for(root.join(WorkflowPaths::DOWNLOAD_DIR_NAME))
      @backup_store = Paperboy::FileStore.for(root.join(WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME))
      @download_prefix = nil
      @backup_prefix = nil
    end
  end

  def shortcut_backed?
    @shortcut_backed
  end

  def target_exists?(name)
    @download_store.exist?(relative_name(name))
  end

  def prepare!
    @download_store.mkdir(@download_prefix)
    @backup_store.mkdir(@backup_prefix)
  end

  def copy(source, name)
    @download_store.copy(source, relative_name(name))
  end

  def write(name, content)
    Tempfile.create('paperboy-download') do |file|
      file.binmode
      file.write(content)
      file.flush
      copy(file.path, name)
    end
  end

  def copy_source(source, name)
    return copy(source, name) if @download_prefix.nil?

    @download_store.with_download(relative_name(source.basename.to_s)) do |local_source|
      copy(local_source, name)
    end
  end

  def backup_existing(name)
    return unless target_exists?(name)

    backup = next_backup_name(name)
    @download_store.with_download(relative_name(name)) do |source|
      @backup_store.copy(source, relative_backup_name(backup))
    end
    backup
  end

  def next_backup_name(name)
    date = Time.now.strftime('%Y-%m-%d')
    basename = File.basename(name)
    pattern = /\A#{Regexp.escape(date)}-(\d{3})-#{Regexp.escape(basename)}\z/
    next_number = @backup_store.entries(@backup_prefix).filter_map do |entry|
      match = entry.fetch(:name).match(pattern)
      match && match[1].to_i
    end.max.to_i + 1
    format('%s-%03d-%s', date, next_number, basename)
  end

  def display_path(name)
    @download_store.path.join(relative_name(name))
  end

  def with_workspace
    return yield unless shortcut_backed?

    Dir.mktmpdir('paperboy-download-workspace') do |directory|
      workspace = Pathname.new(directory)
      workspace.join(WorkflowPaths::DOWNLOAD_DIR_NAME).mkpath
      workspace.join(WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME).mkpath
      yield workspace
    end
  end

  def publish_workspace_file(workspace, name)
    source = Pathname(workspace).join(WorkflowPaths::DOWNLOAD_DIR_NAME, name)
    return unless source.file?

    copy(source, name)
    source
  end

  private

  def relative_name(name)
    [@download_prefix, name.to_s].compact.join('/')
  end

  def relative_backup_name(name)
    [@backup_prefix, name.to_s].compact.join('/')
  end
end
