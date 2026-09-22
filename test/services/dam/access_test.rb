# frozen_string_literal: true

require 'test_helper'

module Dam
  # What the DAM access rules let one person see and do.
  class AccessTest < ActiveSupport::TestCase
    MEMBERS = 7

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      [Dam::AccessRuleGrantee, Dam::AccessRule, Dam::MetadataValue, Dam::MetadataField, Dam::Asset].each(&:delete_all)
      Dam::MetadataField.create!(key: 'usage_rights', label: 'Usage rights', field_type: 'select',
                                 options: ['Internal only', 'Public'].to_json)
      @internal = build_asset('Internal photo', usage_rights: 'Internal only')
      @public = build_asset('Public photo', usage_rights: 'Public')
    end

    # A rule left behind would hide assets from every other DAM test.
    teardown { [Dam::AccessRuleGrantee, Dam::AccessRule].each(&:delete_all) }

    test 'with no rules everyone sees and may do everything' do
      access = outsider

      assert_equal [@internal, @public].map(&:id).sort, access.viewable(Dam::Asset.all).pluck(:id).sort
      assert access.can?(@internal, :publish)
    end

    test 'a rule hides what it covers from everyone it does not name' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS })

      assert_equal [@public.id], outsider.viewable(Dam::Asset.all).pluck(:id)
      assert_not outsider.can?(@internal)
      assert outsider.can?(@public, :download), 'an asset no rule covers stays fully open'
    end

    test 'the people a rule names see its assets, and do only what it allows' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS })
      member = Dam::Access.new(employee_id: '42', group_ids: [MEMBERS])

      assert_includes member.viewable(Dam::Asset.all).pluck(:id), @internal.id
      assert member.can?(@internal, :view)
      assert_not member.can?(@internal, :download)
      assert_empty member.permitted(Dam::Asset.where(id: @internal.id), :download)
    end

    test 'several matching rules add up' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS })
      rule!(name: 'Downloads', can_download: true, grants: { grantee_type: 'employee', employee_id: '42' })
      member = Dam::Access.new(employee_id: '42', group_ids: [MEMBERS])

      assert member.can?(@internal, :download)
      assert_not member.can?(@internal, :share)
      assert_equal [@internal.id], member.permitted(Dam::Asset.where(id: @internal.id), :download).pluck(:id)
    end

    test 'an org grantee covers everyone whose chain sits inside it' do
      rule!(grants: { grantee_type: 'org', agency_id: 'GSA' })

      assert Dam::Access.new(employee_id: '42', org_chain: { agency_id: 'GSA', division_id: 'D1' }).can?(@internal)
      assert_not Dam::Access.new(employee_id: '42', org_chain: { agency_id: 'HCA' }).can?(@internal)
    end

    test 'a rule can key on where the asset is filed' do
      filed = build_asset('Filed photo', agency_id: 'GSA')
      rule = Dam::AccessRule.create!(name: 'GSA only', agency_id: 'GSA')
      rule.grantees.create!(grantee_type: 'group', group_id: MEMBERS)

      assert_not outsider.can?(filed)
      assert outsider.can?(@internal)
      assert Dam::Access.new(group_ids: [MEMBERS]).can?(filed)
    end

    test 'uploaders and admins are never locked out' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS })
      @internal.update!(uploaded_by_id: '99')

      assert Dam::Access.new(employee_id: '99').can?(@internal, :edit)
      assert_includes Dam::Access.new(employee_id: '99').viewable(Dam::Asset.all).pluck(:id), @internal.id
      assert Dam::Access.new(admin: true).can?(@internal, :publish)
    end

    test 'a switched-off rule restricts nothing' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS }).update!(active: false)

      assert outsider.can?(@internal)
    end

    test 'deleting a field does not lift a rule built on it' do
      rule!(grants: { grantee_type: 'group', group_id: MEMBERS })
      Dam::MetadataField.where(key: 'usage_rights').delete_all

      assert_not outsider.can?(@internal)
      assert outsider.can?(@public)
      assert Dam::Access.new(group_ids: [MEMBERS]).can?(@internal)
    end

    test 'a condition that cannot be read keeps restricting but grants nothing' do
      filed = build_asset('Filed photo', agency_id: 'GSA')
      rule = Dam::AccessRule.create!(name: 'GSA', agency_id: 'GSA')
      rule.grantees.create!(grantee_type: 'group', group_id: MEMBERS)
      rule.update_column(:conditions, [{ field: 'usage_rights', operator: 'after', value: 'soon' }].to_json)
      member = Dam::Access.new(group_ids: [MEMBERS])

      assert rule.reload.broken?
      assert_not outsider.can?(filed)
      assert_not member.can?(filed)
      assert_not_includes member.viewable(Dam::Asset.all).pluck(:id), filed.id
    end

    test 'a rule must narrow the library' do
      rule = Dam::AccessRule.new(name: 'Everything')

      assert_not rule.valid?
      assert_match(/whole library/, rule.errors.full_messages.to_sentence)
    end

    private

    def outsider = Dam::Access.new(employee_id: '1', group_ids: [], org_chain: {})

    def rule!(grants:, name: 'Internal media', **flags)
      rule = Dam::AccessRule.create!(name: name, **flags,
                                     condition_rows: [{ field: 'usage_rights', operator: 'equals',
                                                        value: 'Internal only' }])
      rule.grantees.create!(grants)
      rule
    end

    def build_asset(title, usage_rights: nil, **attributes)
      asset = Dam::Asset.create!(title: title, media_type: 'image', **attributes)
      asset.metadata_values.create!(field_key: 'usage_rights', value: usage_rights) if usage_rights
      asset
    end
  end
end
