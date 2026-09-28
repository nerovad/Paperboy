# frozen_string_literal: true

module Aim
  # Base controller for the Automated Invoice Management app. Every AIM
  # controller inherits from this so the ACL gate below is applied
  # consistently.
  class BaseController < ApplicationController
    before_action :require_app_access

    private

    # AIM's front door asks only that someone is signed in to Paperboy (Joshua,
    # 2026-09-25): their AIM account decides the rest. Not on the AIM list, they
    # get Upload, which is open to everyone signed in anyway; on it, their queue
    # and their BUs' shared queues; BU Admins and AIM Admins more. Every screen
    # behind this door checks the account itself. The ACL application grant for
    # AIM now only decides whether AIM shows in Paperboy's app switcher.
    def require_app_access
      return if current_user.present?

      redirect_to root_path, alert: 'Sign in to Paperboy first.'
    end

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

    # Anyone signed in to Paperboy, whether or not they hold the AIM app: the
    # screens that let people hand an invoice to someone's queue.
    def require_signed_in
      return if current_user.present?

      redirect_to root_path, alert: 'Sign in to Paperboy first.'
    end

    # The queue page an invoice was opened from -- a numbered queue, My Queue,
    # a shared queue, or a person's queue on the Admin screen -- so Return to
    # Queue and the redirect after a review action go back there.
    def remember_queue_page
      session[:aim_queue_page] = request.fullpath
    end

    def queue_return_path
      remembered = session[:aim_queue_page].to_s
      return remembered if remembered.start_with?('/aim/')

      helpers.aim_queue_access? ? aim_invoices_path(queue: @queue) : aim_my_queue_path
    end
    helper_method :queue_return_path

    def current_user_email
      session.dig(:user, 'email') || session.dig('user', 'email') || 'Unknown User'
    end

    def current_user_name
      user = session[:user] || session['user'] || {}
      [user['first_name'], user['last_name']].compact_blank.join(' ').presence
    end

    def current_user_employee_id
      user = session[:user] || session['user'] || {}
      user['employee_id'].presence&.to_i
    end

    def current_user_unit
      user = session[:user] || session['user'] || {}
      user['unit'].presence
    end
  end
end
