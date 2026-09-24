# frozen_string_literal: true

require 'singleton'

module Aim
  # Where AIM's files are, as this server sees them. AIM v2 has no queue
  # folders: the PDF lands in the store at intake and never moves, and the
  # other folders are where a copy goes at the end -- the Laserfiche import
  # folder, the archive, the deleted and rejected folders -- plus the drop
  # tree people put scans in and the worker install folder the seed tasks
  # read from.
  #
  # Every path comes from a LockBox variable, written the Windows way, and is
  # translated to this server's mount. Nothing is guessed: a folder that is
  # not configured is nil from #path_for and an error from #path_for!.
  class InvoiceDirectoryService
    include Singleton

    # The screens' queues, under the name the command palette
    # (NavigationCatalog) has always asked this service for. They are the
    # invoice rows' queues now; see Aim::InvoiceQueues.
    BACKEND_QUEUES = Aim::Invoice::QUEUES

    PATH_ENV = {
      store: 'AIM_STORE_DIR',
      processed: 'AIM_PROCESSED_DIR',
      archive: 'AIM_ARCHIVE_DIR',
      deleted: 'AIM_DELETED_DIR',
      rejected: 'AIM_REJECTED_DIR',
      drop: 'AIM_BASE_DIR',
      program: 'AIM_PROGRAM_DIR'
    }.freeze

    # Lenient reader: nil when the folder is not configured.
    def path_for(key)
      env_name = PATH_ENV[key.to_s.to_sym]
      return unless env_name

      translated_env(env_name)
    end

    # Strict reader. Raises MissingConfiguration naming the variable, so code
    # about to write a file fails loudly rather than writing to a guess.
    def path_for!(key)
      env_name = PATH_ENV[key.to_s.to_sym]
      raise MissingConfiguration, "#{key} is not an AIM folder." if env_name.nil?

      path = translated_env(env_name)
      raise MissingConfiguration.for(env_name, "The AIM #{key} folder") if path.blank?

      path
    end

    def store_dir = path_for!(:store)
    def processed_dir = path_for!(:processed)
    def archive_dir = path_for!(:archive)
    def deleted_dir = path_for!(:deleted)
    def rejected_dir = path_for!(:rejected)
    def drop_dir = path_for!(:drop)
    def program_dir = path_for!(:program)

    def to_windows_path(linux_path)
      return if linux_path.blank?

      linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil)
      windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil)
      return linux_path.to_s if linux_base.blank? || windows_base.blank?

      linux_path.to_s.gsub(linux_base, windows_base).tr('/', '\\')
    end

    def translate_path(path)
      return if path.blank?

      linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil)
      windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil)
      return path.to_s.tr('\\', '/') if linux_base.blank? || windows_base.blank?

      path.to_s.gsub(windows_base, linux_base).tr('\\', '/')
    end

    private

    def translated_env(name)
      translate_path(ENV.fetch(name, nil))
    end
  end
end
