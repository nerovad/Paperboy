# frozen_string_literal: true

module Aim
  # Base controller for the Automated Invoice Management app. Every AIM
  # controller inherits from this.
  #
  # AIM's front door asks only that someone is signed in to Paperboy (Joshua,
  # 2026-09-25) -- ApplicationController#require_sign_in, which every AIM
  # screen runs -- and their AIM account decides the rest. Not on the AIM
  # list, they get Upload, which is open to everyone signed in anyway; on it,
  # their queue and their BUs' shared queues; BU Admins and AIM Admins more.
  # Every screen behind this door checks the account itself, with the
  # require_* filters below. The ACL application grant for AIM only decides
  # whether AIM shows in Paperboy's app switcher.
  class BaseController < ApplicationController
    private

    # Who may reach the processing queues lives in Aim::AccessHelper, so the
    # command palette can ask it from apps where no AIM controller is running.
    def require_aim_admin
      return if helpers.aim_queue_access?

      redirect_to aim_root_path, alert: 'Only AIM Admins can open that page.'
    end

    # Managing who works AIM: aim_admin and system admins only.
    def require_aim_user_admin
      return if helpers.aim_user_admin?

      redirect_to aim_root_path, alert: 'Only AIM admins manage AIM users.'
    end

    # The Fiscal stage: Fiscal staff and AIM admins.
    def require_fiscal
      return if helpers.aim_fiscal?

      redirect_to aim_root_path, alert: 'Only Fiscal staff and AIM admins work the Fiscal queue.'
    end

    # Managing people: AIM admins everywhere, BU Admins in their own BUs.
    def require_people_manager
      return if helpers.aim_manages_people?

      redirect_to aim_root_path, alert: 'Only AIM admins and BU Admins manage AIM users.'
    end

    # A list page to come back to: remember_return(:aim_queue_page) on the
    # list, remembered_return(:aim_queue_page, '/aim/') { fallback } after the
    # work. Only a path under +prefix+ is honoured, so the session
    # can never send anyone off AIM.
    def remember_return(key)
      session[key] = request.fullpath
    end

    def remembered_return(key, prefix)
      remembered = session[key].to_s
      remembered.start_with?(prefix) ? remembered : yield
    end

    # The queue page an invoice was opened from -- a numbered queue, My Queue,
    # a shared queue, or a person's queue on the Admin screen -- so Return to
    # Queue and the redirect after a review action go back there.
    def remember_queue_page = remember_return(:aim_queue_page)

    def queue_return_path
      remembered_return(:aim_queue_page, '/aim/') do
        helpers.aim_queue_access? ? aim_invoices_path(queue: @queue) : aim_my_queue_path
      end
    end
    helper_method :queue_return_path

    # A list page that reads the database: runs the block, and if the database
    # cannot be read logs +what+ went wrong, shows +alert+ (when given) and
    # leaves the page its +empty+ instance variables to draw from.
    #
    #   reading_database('list the coding rules', alert: '...', empty: { rules: [] }) { ... }
    def reading_database(what, empty:, alert: nil, errors: ActiveRecord::ActiveRecordError)
      yield
    rescue *Array(errors) => e
      Rails.logger.error "AIM could not #{what}: #{e.message}"
      empty.each { |name, value| instance_variable_set(:"@#{name}", value) }
      flash.now[:alert] = alert if alert
    end

    # The signed-in person, as AIM names them. ApplicationController has
    # already turned away anyone without a session, so current_user is here.
    def current_user_email = current_user&.email.presence || 'Unknown User'
    def current_user_name = current_user&.full_name.presence
    def current_user_employee_id = current_user&.employee_id.presence&.to_i

    # SessionUser does not carry the unit, so it is read from the session the
    # sign-in wrote.
    def current_user_unit = session.dig(:user, 'unit').presence
  end
end
