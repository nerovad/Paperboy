# frozen_string_literal: true

# app/services/forms/duplicator/acl_copier.rb

module Forms
  class Duplicator
    # Gives a copied form the same ACL a source form has. Three kinds of key
    # name a form, and each is rewritten for the copy:
    #
    #   form               <template id>          may open the form
    #   record_view/_edit  form-<template id>     its Records grid
    #   submission_action  <action>:<ClassName>   per-action submission rights
    #
    # Dropdown, feature and application keys name no form and are left alone.
    # Group and org-scope grants are both copied.
    class AclCopier
      TYPES = %w[form record_view record_edit submission_action].freeze

      # +source+ is the form whose keys are read: the original when copying,
      # the copy when taking a failed copy's grants back.
      def initialize(source)
        @source = source
      end

      # [groups, org scopes] holding any of the source's keys, for the
      # dialog's summary of what the access box copies.
      def counts
        [group_scope.distinct.count(:GroupID), org_scope.count]
      end

      def copy_to(template)
        keys = key_map(template)

        group_scope.pluck(:GroupID, :Permission_Type, :Permission_Key).each do |group_id, type, key|
          GroupPermission.find_or_create_by!(GroupID: group_id, Permission_Type: type, Permission_Key: keys.fetch(key))
        end

        org_scope.find_each do |perm|
          attrs = perm.attributes.slice('agency_id', 'division_id', 'department_id', 'unit_id', 'permission_type')
          OrgPermission.find_or_create_by!(attrs.merge('permission_key' => keys.fetch(perm.permission_key)))
        end
      end

      # Deletes every grant holding this form's keys. Run against a copy
      # whose duplication failed: nothing else carries the copy's id or class
      # name, so its grants can be found without having been tracked.
      def remove_all
        group_scope.delete_all
        org_scope.delete_all
      end

      private

      def id_keys = [@source.id.to_s, "form-#{@source.id}"]
      def action_pattern = "%:#{@source.class_name}"

      def group_scope
        GroupPermission.where(Permission_Type: TYPES, Permission_Key: id_keys)
                       .or(GroupPermission.where(Permission_Type: 'submission_action')
                                          .where('Permission_Key LIKE ?', action_pattern))
      end

      def org_scope
        OrgPermission.where(permission_type: TYPES, permission_key: id_keys)
                     .or(OrgPermission.where(permission_type: 'submission_action')
                                      .where('permission_key LIKE ?', action_pattern))
      end

      # old key => new key for everything the source holds.
      def key_map(template)
        held = group_scope.pluck(:Permission_Key) | org_scope.pluck(:permission_key)
        held.index_with do |key|
          case key
          when @source.id.to_s then template.id.to_s
          when "form-#{@source.id}" then "form-#{template.id}"
          else key.sub(/:#{Regexp.escape(@source.class_name)}\z/, ":#{template.class_name}")
          end
        end
      end
    end
  end
end
