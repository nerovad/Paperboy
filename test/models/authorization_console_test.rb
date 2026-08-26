# frozen_string_literal: true

require 'test_helper'

# The registry the console picker, the console switcher, the access checks and
# the form builder's routing dropdown all read from.
class AuthorizationConsoleTest < ActiveSupport::TestCase
  test 'every console is registered under a distinct key' do
    keys = AuthorizationConsole::ALL.map(&:key)

    assert_equal keys.uniq, keys
    assert_includes keys, AuthorizationConsole::CIR.key
  end

  test 'every console names a route helper that exists' do
    AuthorizationConsole::ALL.each do |console|
      assert Rails.application.routes.url_helpers.respond_to?(console.route_name),
             "#{console.key} points at #{console.route_name}, which is not a route"
    end
  end

  test 'routing keys stay unique across consoles' do
    keys = AuthorizationConsole.routing_keys

    assert_equal keys.uniq, keys
  end

  test 'the CIR routing key resolves back to the CIR console' do
    assert_equal AuthorizationConsole::CIR, AuthorizationConsole.console_for_routing_key('cir_location')
    assert_equal 'CIR Incident Manager (by location)', AuthorizationConsole.routing_label('cir_location')
  end

  test 'the parking and safety routing keys are untouched by the new console' do
    assert_equal AuthorizationConsole::SERVICES, AuthorizationConsole.console_for_routing_key('P')
    assert_equal AuthorizationConsole::HCA_SAFETY, AuthorizationConsole.console_for_routing_key('hca_safety')
  end

  # --- ACL rights -------------------------------------------------------------

  test 'every console issues one key per right, namespaced to itself' do
    cir_keys = AuthorizationConsole::RIGHT_KEYS.map { |r| AuthorizationConsole.permission_key('cir', r) }

    assert_equal %w[cir:read cir:write cir:delete], cir_keys

    keys = AuthorizationConsole.permission_keys

    assert_equal AuthorizationConsole::ALL.size * AuthorizationConsole::RIGHT_KEYS.size, keys.size
    assert_equal keys.uniq, keys
  end

  test 'write and delete each imply read, so no grant is unreachable' do
    assert_equal Set['read'], AuthorizationConsole.rights_from_keys('cir', Set['cir:read'])
    assert_equal Set['read', 'write'], AuthorizationConsole.rights_from_keys('cir', Set['cir:write'])
    assert_equal Set['read', 'delete'], AuthorizationConsole.rights_from_keys('cir', Set['cir:delete'])
    assert_equal Set['read', 'write', 'delete'],
                 AuthorizationConsole.rights_from_keys('cir', Set['cir:write', 'cir:delete'])
  end

  test 'holding nothing on a console yields nothing' do
    assert_empty AuthorizationConsole.rights_from_keys('cir', Set.new)
  end

  test 'rights on one console say nothing about another' do
    granted = Set['cir:write', 'cir:delete']

    assert_empty AuthorizationConsole.rights_from_keys('services', granted)
    assert_empty AuthorizationConsole.rights_from_keys('hca_safety', granted)
  end

  test 'the ACL catalogue offers every console and every right' do
    catalogue = AuthorizationConsole.permission_catalog

    assert_equal AuthorizationConsole::ALL.map(&:key), catalogue.pluck(:key)
    assert_equal AuthorizationConsole::ALL.map(&:label), catalogue.pluck(:label)
    assert_equal AuthorizationConsole.permission_keys.sort,
                 catalogue.flat_map { |c| c[:rights].map { |r| r[:permission_key] } }.sort
  end

  test 'an unknown routing key resolves to no console and routes to nobody' do
    assert_nil AuthorizationConsole.console_for_routing_key('nonsense')
    assert_empty AuthorizationConsole.approver_ids_for('nonsense', nil)
    assert_nil AuthorizationConsole.inbox_conditions_for('nonsense', ['1'])
  end
end
