# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'
require_relative '../../../../lib/paperboy/file_store'
require_relative '../constants/workflow_paths'

# Gives DataRunner child commands a local workspace when its output root is a
# shortcut-backed folder, then publishes successful stage files remotely.
class DataRunnerWorkspace
  STAGES = [
    WorkflowPaths::DOWNLOAD_DIR_NAME,
    WorkflowPaths::NORMALIZED_DIR_NAME,
    WorkflowPaths::SQL_MAP_DIR_NAME,
    WorkflowPaths::SQL_SCHEMA_DIR_NAME,
    WorkflowPaths::APPLIED_DIR_NAME,
    WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME
  ].freeze

  def initialize(root: WorkflowPaths::OUTPUT_ROOT)
    @root = Pathname(root)
    @store = Paperboy::FileStore.for(@root) if shortcut_backed?
  end

  def run(environment = {})
    return yield(environment) unless shortcut_backed?

    Dir.mktmpdir('paperboy-data-runner') do |directory|
      workspace = Pathname.new(directory)
      prepare(workspace)
      materialize(workspace)
      child_environment = environment.merge('DATARUNNER_OUTPUT_ROOT' => workspace.to_s)
      success = yield(child_environment)
      publish(workspace) if success
      success
    end
  end

  private

  def shortcut_backed?
    @root.extname.casecmp?('.lnk')
  end

  def prepare(workspace)
    STAGES.each { |stage| workspace.join(stage).mkpath }
  end

  def materialize(workspace)
    STAGES.each do |stage|
      @store.walk(stage).each do |entry|
        target = workspace.join(entry.fetch(:name))
        target.dirname.mkpath
        @store.with_download(entry.fetch(:name)) { |source| FileUtils.cp(source, target) }
      end
    end
  end

  def publish(workspace)
    workspace.glob('**/*').select(&:file?).each do |path|
      relative = path.relative_path_from(workspace).to_s
      @store.copy(path, relative)
    end
  end
end
