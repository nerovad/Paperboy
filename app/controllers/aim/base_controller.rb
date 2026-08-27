# frozen_string_literal: true

module Aim
  # Base controller for the Automated Invoice Management app. Every Automated Invoice Management controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    before_action :require_app_access
    before_action :load_aim_sidebar_counts

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it Automated Invoice Management would stay reachable by
    # typing the URL. Access is granted per group or org level under
    # ACL > Applications; system admins bypass it.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('aim')

      redirect_to root_path, alert: 'You do not have access to Automated Invoice Management.'
    end

    # Who may reach the processing queues lives in Aim::AccessHelper, so the
    # command palette can ask it from apps where no AIM controller is running.
    def require_aim_admin
      return if helpers.aim_queue_access?

      redirect_to aim_root_path, alert: 'You do not have access to AIM processing queues.'
    end

    def load_aim_sidebar_counts
      @aim_queue_statuses = {}
      @aim_queue_counts = {}

      Aim::InvoiceDirectoryService::BACKEND_QUEUES.each_key do |queue|
        path = Aim::InvoiceDirectoryService.instance.path_for(queue)
        @aim_queue_statuses[queue] = aim_queue_directory_status(path)
        @aim_queue_counts[queue] = aim_queue_directory_count(path)
      end
    rescue StandardError => e
      Rails.logger.error "Failed to load AIM queue counts: #{e.message}"
      @aim_queue_statuses = {}
      @aim_queue_counts = {}
    end

    def aim_queue_directory_count(path)
      return 0 if path.blank? || !Dir.exist?(path.to_s)

      Dir.glob(File.join(path.to_s, '*')).count { |file_path| File.directory?(file_path) }
    end

    def aim_queue_directory_status(path)
      return { connected: false, path: nil, message: 'Path is not configured.' } if path.blank?
      return { connected: false, path: path.to_s, message: 'Queue folder is not reachable.' } unless Dir.exist?(path.to_s)

      { connected: true, path: path.to_s, message: 'Connected.' }
    end
  end
end
