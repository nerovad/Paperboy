# frozen_string_literal: true

require 'singleton'

module Aim
  class InvoiceDirectoryService
    include Singleton

    BACKEND_QUEUES = {
      ai_queue: {
        label: 'AI Queue',
        description: 'Spooled invoices waiting for AI extraction.',
        css_class: 'aim-card-neutral'
      },
      action_needed: {
        label: 'Action Needed',
        description: 'Invoices missing critical extraction data.',
        css_class: 'aim-card-danger'
      },
      vendor_review: {
        label: 'Vendor Review',
        description: 'Unknown vendors requiring normalization.',
        css_class: 'aim-card-warning'
      },
      batch_split: {
        label: 'Batch Split',
        description: 'PDFs containing multiple invoices to split.',
        css_class: 'aim-card-info'
      },
      low_confidence_review: {
        label: 'Low Confidence Review',
        description: 'Invoices routed for manual confidence review.',
        css_class: 'aim-card-warning'
      },
      sql_failed: {
        label: 'SQL Failed',
        description: 'Invoices that failed downstream SQL processing.',
        css_class: 'aim-card-danger'
      },
      rejected: {
        label: 'Rejected',
        description: 'Rejected invoices awaiting archive or follow-up.',
        css_class: 'aim-card-neutral'
      }
    }.freeze

    PATH_ENV = {
      action_needed: 'AIM_ACTION_NEEDED_DIR',
      vendor_review: 'AIM_VENDOR_REVIEW_DIR',
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

    def path_for(queue)
      queue = queue.to_s
      return ai_queue_dir if queue == 'ai_queue'

      env_name = PATH_ENV[queue.to_sym]
      return unless env_name

      translated_env(env_name)
    end

    def action_needed_dir = path_for(:action_needed)
    def vendor_review_dir = path_for(:vendor_review)
    def batch_split_dir = path_for(:batch_split)
    def low_confidence_review_dir = path_for(:low_confidence_review)
    def sql_queue_dir = path_for(:sql_queue)
    def sql_failed_dir = path_for(:sql_failed)
    def user_approval_dir = path_for(:user_approval)
    def rejected_dir = path_for(:rejected) || queue_base_child('_REJECTED')
    def ready_to_learn_dir = path_for(:ready_to_learn) || queue_base_child('_BACK_END', '_READY_TO_LEARN')
    def reprocess_dir = path_for(:reprocess) || queue_base_child('_REPROCESS_QUEUE')
    def deleted_dir = path_for(:deleted) || queue_base_child('_DELETED')

    def ai_queue_dir
      translated_env('AIM_AI_QUEUE_DIR') || queue_base_child('_AI_QUEUE', fallback_from: sql_queue_dir)
    end

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

    def queue_base_child(*children, fallback_from: nil)
      base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil).presence
      base ||= File.dirname(fallback_from) if fallback_from.present?
      return if base.blank?

      File.join(base, *children)
    end
  end
end
