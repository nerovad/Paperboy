# frozen_string_literal: true

module Aim
  # AIM administration: who works AIM (item a.1). Budget unit coverage and
  # each BU's shared queue follow in a.2 and a.3. Only AIM admins reach it.
  class AdminController < BaseController
    before_action :require_aim_user_admin

    def index
      members = Aim::Member.all.index_by(&:employee_id)
      via_groups = Aim::Users.group_employee_ids.to_set
      open_counts = Aim::Invoice.where(assigned_employee_id: members.keys + via_groups.to_a)
                                .where.not(state: Aim::Invoice::TERMINAL_STATES + Aim::Member::HANDS_OFF_STATES)
                                .group(:assigned_employee_id).count
      @people = Aim::Users.all.map do |employee|
        { employee: employee, member: members[employee.id], via_group: via_groups.include?(employee.id),
          open: open_counts.fetch(employee.id, 0) }
      end
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error "AIM could not list its users: #{e.message}"
      @people = []
      flash.now[:alert] = 'The AIM users could not be read.'
    end
  end
end
