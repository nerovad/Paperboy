# frozen_string_literal: true

module Aim
  # The people an invoice can be handed to: everyone who can work the AIM
  # queues. That is the aim_admin, aim_staff and system_admins groups, which
  # predate the ACL section, plus every group granted AIM's Processing Queues
  # feature under ACL. Employees live in GSABSS and the groups in Paperboy,
  # so the two are joined by id here rather than in SQL.
  module Users
    GROUPS = %w[system_admins aim_admin aim_staff].freeze
    FEATURE = AppFeature.permission_key('aim', 'processing_queues')

    module_function

    def all
      group_ids = Group.where(Group_Name: GROUPS).pluck(:GroupID) +
                  GroupPermission.where(Permission_Key: FEATURE).pluck(:GroupID)
      ids = EmployeeGroup.where(GroupID: group_ids.uniq).pluck(:EmployeeID).uniq
      Employee.where(id: ids).order(:last_name, :first_name)
    end

    # Whether this employee has a queue: is one of the people who work AIM.
    def member?(employee_id)
      employee_id.present? && all.exists?(id: employee_id)
    rescue ActiveRecord::ActiveRecordError
      false
    end

    # Display names, as a queue is named after a person: "First Last".
    def names
      all.map { |employee| "#{employee.first_name} #{employee.last_name}".squish }.compact_blank.uniq
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn "AIM could not list its users: #{e.message}"
      []
    end
  end
end
