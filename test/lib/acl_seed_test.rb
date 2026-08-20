# frozen_string_literal: true

require 'test_helper'

# The ACL file has to survive the one thing that differs between
# Paperboy_Dev / _Stage / _Prod: form_templates.id. These cover the identity
# rewriting and the merge that unions two environments into one file. Neither
# touches the database — FormKey.index takes any collection of templates.
class AclSeedTest < ActiveSupport::TestCase
  Template = Struct.new(:id, :class_name, :name)

  FormKey = Paperboy::AclSeed::FormKey

  def dev_forms
    FormKey.index([Template.new(51, 'TeleworkLogForm', 'Telework Log'), Template.new(33, 'SafetyReport', 'Safety Reporting')])
  end

  def prod_forms
    FormKey.index([Template.new(40, 'TeleworkLogForm', 'Telework Log')])
  end

  test 'parts recognises the two key shapes that hold a form id' do
    assert_equal ['', '51'], FormKey.parts('form', '51')
    assert_equal ['form-', '33'], FormKey.parts('record_view', 'form-33')
    assert_nil FormKey.parts('dropdown', 'inbox')
    assert_nil FormKey.parts('form', 'creative_job_request')
  end

  test 'identity records the class name behind a form id' do
    assert_equal({ 'class' => 'TeleworkLogForm', 'label' => 'Telework Log' }, FormKey.identity('form', '51', dev_forms))
    assert_equal({ 'class' => 'SafetyReport', 'label' => 'Safety Reporting' }, FormKey.identity('record_edit', 'form-33', dev_forms))
    assert_empty FormKey.identity('dropdown', 'inbox', dev_forms)
    assert_empty FormKey.identity('form', '99', dev_forms), 'an id with no template must not be dumped as portable'
  end

  test 'resolve rewrites a dev form id to the local one' do
    row = { 'type' => 'form', 'key' => '51', 'class' => 'TeleworkLogForm', 'label' => 'Telework Log' }
    assert_equal ['40', nil], FormKey.resolve(row, prod_forms)
  end

  test 'resolve keeps the record_ prefix' do
    row = { 'type' => 'record_view', 'key' => 'form-51', 'class' => 'TeleworkLogForm' }
    assert_equal ['form-40', nil], FormKey.resolve(row, prod_forms)
  end

  test 'resolve passes stable keys through untouched' do
    assert_equal ['inbox', nil], FormKey.resolve({ 'type' => 'dropdown', 'key' => 'inbox' }, prod_forms)
    assert_equal ['creative_job_request', nil], FormKey.resolve({ 'type' => 'form', 'key' => 'creative_job_request' }, prod_forms)
  end

  test 'resolve refuses a form this database does not have rather than granting the id' do
    row = { 'type' => 'form', 'key' => '33', 'class' => 'SafetyReport', 'label' => 'Safety Reporting' }
    key, refusal = FormKey.resolve(row, prod_forms)
    assert_nil key
    assert_match(/SafetyReport does not exist/, refusal)
  end

  test 'resolve refuses a bare form id, which means nothing outside its own database' do
    key, refusal = FormKey.resolve({ 'type' => 'form', 'key' => '40' }, prod_forms)
    assert_nil key
    assert_match(/re-run acl:dump/, refusal)
  end

  test 'resolve falls back to the form name when a row predates class names' do
    row = { 'type' => 'form', 'key' => '51', 'label' => 'Telework Log' }
    assert_equal ['40', nil], FormKey.resolve(row, prod_forms)
  end

  test 'merge unions groups and does not duplicate a form grant that has a different id per database' do
    file = { 'groups' => [{ 'name' => 'IT_Support', 'description' => 'Prod copy',
                            'permissions' => [{ 'type' => 'form', 'key' => '40', 'class' => 'TeleworkLogForm', 'label' => 'Telework Log' }] }],
             'org_permissions' => [] }
    dev = { 'groups' => [{ 'name' => 'it_support', 'description' => nil,
                           'permissions' => [{ 'type' => 'form', 'key' => '51', 'class' => 'TeleworkLogForm', 'label' => 'Telework Log' },
                                             { 'type' => 'dropdown', 'key' => 'inbox' }] },
                         { 'name' => 'HCA_Test', 'description' => 'Dev only', 'permissions' => [] }],
            'org_permissions' => [] }

    merged = Paperboy::AclSeed.merge(file, dev)
    names = merged['groups'].map { |group| group['name'] }
    assert_equal %w[HCA_Test IT_Support], names.sort
    it_support = merged['groups'].find { |group| group['name'].casecmp?('IT_Support') }
    assert_equal [%w[dropdown inbox], %w[form TeleworkLogForm]],
                 it_support['permissions'].map { |perm| [perm['type'], Paperboy::AclSeed::FormKey.identity_key(perm)] }.sort
    assert_equal 'Prod copy', it_support['description']
  end

  test 'merge unions org grants so a dev grant is not re-entered by hand in prod' do
    file = { 'groups' => [], 'org_permissions' => [{ 'agency_id' => 'AAA', 'type' => 'dropdown', 'key' => 'inbox' }] }
    dev = { 'groups' => [],
            'org_permissions' => [{ 'agency_id' => 'AAA', 'type' => 'dropdown', 'key' => 'inbox' },
                                  { 'agency_id' => 'AAA', 'division_id' => 'D1', 'type' => 'form', 'key' => '51', 'class' => 'TeleworkLogForm' }] }

    merged = Paperboy::AclSeed.merge(file, dev)
    assert_equal 2, merged['org_permissions'].size
    assert_includes merged['org_permissions'].map { |row| row['class'] }, 'TeleworkLogForm'
  end

  test 'merge keeps the row that names a form over one that only holds an id' do
    file = { 'groups' => [], 'org_permissions' => [{ 'agency_id' => 'AAA', 'type' => 'form', 'key' => 'TeleworkLogForm' }] }
    dev = { 'groups' => [], 'org_permissions' => [{ 'agency_id' => 'AAA', 'type' => 'form', 'key' => '51', 'class' => 'TeleworkLogForm' }] }

    merged = Paperboy::AclSeed.merge(file, dev)
    assert_equal 1, merged['org_permissions'].size
    assert_equal 'TeleworkLogForm', merged['org_permissions'].first['class']
  end
end
