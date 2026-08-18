# frozen_string_literal: true

module Pfa
  module Access
    class PermissionSet
      def initialize(org_chain:, group_ids:)
        @org_chain = org_chain
        @group_ids = group_ids
      end

      def keys(permission_type)
        Set.new.tap do |keys|
          keys.merge(global_keys(permission_type))
          keys.merge(org_keys(permission_type))
          keys.merge(group_keys(permission_type))
        end
      rescue StandardError
        Set.new
      end

      private

      attr_reader :org_chain, :group_ids

      def global_keys(permission_type)
        OrgPermission.where(
          agency_id: nil,
          division_id: nil,
          department_id: nil,
          unit_id: nil,
          permission_type: permission_type
        ).pluck(:permission_key)
      end

      def org_keys(permission_type)
        conditions = org_conditions
        return [] if conditions.empty?

        query = conditions.map do |condition|
          OrgPermission.where(condition.merge(permission_type: permission_type))
        end.reduce(:or)
        query.pluck(:permission_key)
      end

      def group_keys(permission_type)
        return [] if group_ids.empty?

        GroupPermission.where(group_id: group_ids, permission_type: permission_type)
                       .pluck(:permission_key)
      end

      def org_conditions
        agency_id = org_chain[:agency_id]
        return [] if agency_id.blank?

        conditions = [{ agency_id: agency_id, division_id: nil, department_id: nil, unit_id: nil }]
        conditions << division_condition(agency_id) if org_chain[:division_id].present?
        conditions << department_condition(agency_id) if org_chain[:department_id].present?
        conditions << unit_condition(agency_id) if org_chain[:unit_id].present?
        conditions
      end

      def division_condition(agency_id)
        {
          agency_id: agency_id,
          division_id: org_chain[:division_id],
          department_id: nil,
          unit_id: nil
        }
      end

      def department_condition(agency_id)
        division_condition(agency_id).merge(department_id: org_chain[:department_id])
      end

      def unit_condition(agency_id)
        department_condition(agency_id).merge(unit_id: org_chain[:unit_id])
      end
    end
  end
end
