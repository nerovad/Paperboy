# frozen_string_literal: true

module Dam
  # One answer to "who does this access rule open its assets to": a group, a
  # single employee, or everyone who sits inside an org level. An org grantee
  # with every level blank is everyone who holds Digital Asset Management —
  # the way to say "anyone may look, but only the comms group may download".
  class AccessRuleGrantee < ApplicationRecord
    self.table_name = 'dam_access_rule_grantees'

    GRANTEE_TYPES = %w[group employee org].freeze
    ORG_LEVELS = ::FormSearch::ORG_LEVELS

    belongs_to :rule, class_name: 'Dam::AccessRule', inverse_of: :grantees
    belongs_to :group, foreign_key: :group_id, optional: true

    before_validation :normalize

    validates :grantee_type, inclusion: { in: GRANTEE_TYPES }
    validates :group_id, presence: true, if: -> { grantee_type == 'group' }
    validates :employee_id, presence: true, if: -> { grantee_type == 'employee' }
    validate :not_a_duplicate

    # Whether the person +access+ describes is one of the people this row names.
    def covers?(access)
      case grantee_type
      when 'group' then access.group_ids.map(&:to_i).include?(group_id.to_i)
      when 'employee' then access.employee_id.present? && access.employee_id == employee_id
      when 'org' then org_covers?(access.org_chain)
      else false
      end
    end

    def org_levels
      ORG_LEVELS.index_with { |level| self[:"#{level}_id"] }.compact_blank
    end

    # How the admin screen names this grantee. +names+ is an optional
    # employee_id => name hash, so a list of rows costs one lookup.
    def label(names = {})
      case grantee_type
      when 'group' then "Group: #{group&.group_name || "##{group_id}"}"
      when 'employee' then "Employee: #{names[employee_id].presence || employee_id}"
      else org_levels.empty? ? 'Everyone with DAM access' : org_label
      end
    end

    private

    def org_label
      search = ::FormSearch.new(org_levels.transform_keys { |level| :"filter_#{level}" })
      search.summary.join(', ')
    end

    # The viewer's chain arrives already normalized to the agencies table's
    # three-character id (EmployeePermissions#resolve_org_chain), and an org
    # grantee is picked from that same table, so the ids compare directly.
    def org_covers?(chain)
      chain = (chain || {}).to_h.symbolize_keys
      org_levels.all? { |level, value| chain[:"#{level}_id"].to_s == value.to_s }
    end

    def normalize
      self.employee_id = employee_id.to_s.strip.presence
      ORG_LEVELS.each do |level|
        attribute = "#{level}_id"
        self[attribute] = self[attribute].to_s.strip.presence
      end
    end

    def not_a_duplicate
      return if rule.nil?

      twin = rule.grantees.where(grantee_type: grantee_type, group_id: group_id, employee_id: employee_id,
                                 **ORG_LEVELS.to_h { |level| [:"#{level}_id", self[:"#{level}_id"]] })
      twin = twin.where.not(id: id) if persisted?
      errors.add(:base, 'This rule already names them.') if twin.exists?
    end
  end
end
