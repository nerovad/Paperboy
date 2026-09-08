# frozen_string_literal: true

require 'singleton'

module Aim
  class InvoiceDirectoryService
    include Singleton

    BACKEND_QUEUES = {
      ai_queue: { label: 'AI Queue', description: 'Spooled invoices waiting for AI extraction.', css_class: 'aim-card-neutral' },
      action_needed: { label: 'Action Needed', description: 'Invoices missing critical extraction data.', css_class: 'aim-card-danger' },
      vendor_review: { label: 'Vendor Review', description: 'Unknown vendors requiring normalization.', css_class: 'aim-card-warning' },
      manual_processing: { label: 'Manual Processing', description: 'Invoices needing full manual entry.', css_class: 'aim-card-warning' },
      batch_split: { label: 'Batch Split', description: 'PDFs containing multiple invoices to split.', css_class: 'aim-card-info' },
      low_confidence_review: { label: 'Low Confidence Review', description: 'Invoices routed for manual review.', css_class: 'aim-card-warning' },
      sql_failed: { label: 'SQL Failed', description: 'Invoices that failed downstream SQL processing.', css_class: 'aim-card-danger' },
      rejected: { label: 'Rejected', description: 'Rejected invoices awaiting archive or follow-up.', css_class: 'aim-card-neutral' }
    }.freeze

    PATH_ENV = {
      ai_queue: 'AIM_AI_QUEUE_DIR',
      action_needed: 'AIM_ACTION_NEEDED_DIR',
      vendor_review: 'AIM_VENDOR_REVIEW_DIR',
      manual_processing: 'AIM_MANUAL_PROCESSING_DIR',
      batch_split: 'AIM_BATCH_SPLIT_DIR',
      low_confidence_review: 'AIM_LOW_CONFIDENCE_REVIEW_DIR',
      sql_queue: 'AIM_SQL_QUEUE_DIR',
      sql_failed: 'AIM_SQL_FAILED_DIR',
      user_approval: 'AIM_USER_APPROVAL_DIR',
      rejected: 'AIM_REJECTED_DIR',
      ready_to_learn: 'AIM_READY_TO_LEARN_DIR',
      reprocess: 'AIM_REPROCESS_QUEUE_DIR',
      deleted: 'AIM_DELETED_DIR',
      gsa_fiscal: 'AIM_GSA_FISCAL_DIR',
      vcfms_hold: 'AIM_VCFMS_HOLD_DIR'
    }.freeze

    # Lenient reader. Returns nil when the queue is not configured, so the
    # sidebar can report "not configured" instead of raising. Never guesses.
    def path_for(queue)
      env_name = PATH_ENV[queue.to_s.to_sym]
      return unless env_name

      translated_env(env_name)
    end

    # Strict reader. Raises MissingConfiguration naming the variable. Every
    # *_dir reader below uses this, so any code about to touch a queue fails
    # loudly rather than writing to a guessed folder.
    def path_for!(queue)
      env_name = PATH_ENV[queue.to_s.to_sym]
      raise MissingConfiguration, "#{queue} is not an AIM queue." if env_name.nil?

      path = translated_env(env_name)
      raise MissingConfiguration.for(env_name, "AIM #{queue} queue") if path.blank?

      path
    end

    def ai_queue_dir = path_for!(:ai_queue)
    def action_needed_dir = path_for!(:action_needed)
    def vendor_review_dir = path_for!(:vendor_review)
    def manual_processing_dir = path_for!(:manual_processing)
    def batch_split_dir = path_for!(:batch_split)
    def low_confidence_review_dir = path_for!(:low_confidence_review)
    def sql_queue_dir = path_for!(:sql_queue)
    def sql_failed_dir = path_for!(:sql_failed)
    def user_approval_dir = path_for!(:user_approval)
    def rejected_dir = path_for!(:rejected)
    def ready_to_learn_dir = path_for!(:ready_to_learn)
    def reprocess_dir = path_for!(:reprocess)
    def deleted_dir = path_for!(:deleted)

    def to_windows_path(linux_path)
      return if linux_path.blank?

      linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil)
      windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil)
      return linux_path.to_s if linux_base.blank? || windows_base.blank?

      linux_path.to_s.gsub(linux_base, windows_base).tr('/', '\\')
    end

    private

    def translated_env(name)
      translate_path(ENV.fetch(name, nil))
    end

    def translate_path(path)
      return if path.blank?

      linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil)
      windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil)
      return path.to_s.tr('\\', '/') if linux_base.blank? || windows_base.blank?

      path.to_s.gsub(windows_base, linux_base).tr('\\', '/')
    end
  end
end
