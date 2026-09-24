# frozen_string_literal: true

module Dam
  # What one person may see and do in the library, under the access rules.
  #
  #   access = Dam::Access.new(employee_id: '1234', group_ids: [7], org_chain: { agency_id: 'GSA' })
  #   access.viewable(Dam::Asset.visible)       # the assets they can see
  #   access.permitted(scope, :download)        # ...and may download
  #   access.can?(asset, :share)                # one asset, one capability
  #
  # The rules are in Dam::AccessRule. In short: an asset no active rule
  # matches is open, as the library always was; an asset some rule matches is
  # open only to people a matching rule covers, and only for what that rule
  # allows. Two people are never restricted: system admins, who have to be
  # able to repair a rule that locked everyone out, and whoever uploaded the
  # asset, who should not lose sight of their own file by tagging it.
  #
  # Build one per request — the rules are loaded once and answers memoized.
  # Feature grants (ACL > Application Features) still apply on top: a rule
  # allowing Publish does not give someone the Publish screen.
  class Access
    CAPABILITIES = [:view, *Dam::AccessRule::CAPABILITIES].freeze

    attr_reader :employee_id, :group_ids, :org_chain

    # For somebody other than the signed-in user: the admin preview, or a job
    # acting on someone's behalf.
    def self.for_employee(employee_id)
      permissions = EmployeePermissions.new(employee_id.to_s)
      new(employee_id: employee_id, group_ids: permissions.current_user_group_ids,
          org_chain: permissions.current_user_org_chain, admin: permissions.system_admin?)
    end

    def initialize(employee_id: nil, group_ids: [], org_chain: {}, admin: false)
      @employee_id = employee_id.to_s.presence
      @group_ids = Array(group_ids)
      @org_chain = org_chain || {}
      @admin = admin
      @matches = {}
    end

    def admin? = @admin

    # Nothing to enforce: an admin, or a library with no active rules.
    def unrestricted? = admin? || rules.empty?

    def rules
      @rules ||= Dam::AccessRule.active.includes(grantees: :group).to_a
    end

    # The active rules that name this person.
    def held_rules
      @held_rules ||= rules.select { |rule| rule.covers?(self) }
    end

    def viewable(scope = Dam::Asset.all) = permitted(scope, :view)

    # +scope+ narrowed to the assets this person may do +capability+ to. Stays
    # a relation, so it pages, counts and composes like the scope it was given.
    def permitted(scope, capability = :view)
      return scope if unrestricted?

      scope.where(id: permitted_ids(capability))
    end

    def can?(asset, capability = :view)
      return false if asset.nil?
      return true if unrestricted? || own?(asset)

      restricting = restricting_rules(asset)
      return true if restricting.empty?

      restricting.any? do |rule|
        rule.covers?(self) && rule.allows?(capability) && !rule.broken?(fields)
      end
    end

    # The active rules that match +asset+, for the admin panel on its page.
    def restricting_rules(asset)
      @matches[asset.id] ||= rules.select { |rule| rule.restricted_assets(fields).exists?(asset.id) }
    end

    private

    def own?(asset)
      employee_id.present? && asset.uploaded_by_id.to_s == employee_id
    end

    # Open assets, the viewer's own uploads, and whatever a rule they hold
    # grants — as a subquery of ids, so a library of any size stays one query.
    def permitted_ids(capability)
      (@permitted_ids ||= {})[capability.to_sym] ||= begin
        restricted = any_of(rules.map { |rule| rule.restricted_assets(fields) })
        ids = Dam::Asset.where.not(id: restricted.select(:id))
        ids = ids.or(Dam::Asset.where(uploaded_by_id: employee_id)) if employee_id.present?

        granted = held_rules.select { |rule| rule.allows?(capability) }.filter_map { |rule| rule.granted_assets(fields) }
        ids = ids.or(Dam::Asset.where(id: any_of(granted).select(:id))) if granted.any?
        ids.select(:id)
      end
    end

    def any_of(scopes)
      scopes.map { |scope| Dam::Asset.where(id: scope.select(:id)) }.reduce(:or)
    end

    def fields
      @fields ||= Dam::MetadataField.all.index_by(&:key)
    end
  end
end
