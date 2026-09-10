# frozen_string_literal: true

require 'test_helper'

# FormCatalog is the list of blank forms behind both search surfaces — the
# Paperboy sidebar and the command palette. What it must never do is offer a
# form the ACL keeps from the viewer, so most of this is about the filtering.
#
# Templates are built in memory and Forms::Template.active is stubbed: the
# catalog only reads their metadata, and the routes it resolves come from
# config/routes.rb rather than from any row.
class FormCatalogTest < ActiveSupport::TestCase
  def template(name:, file_name:, id: nil, **attributes)
    Forms::Template.new(name: name, class_name: file_name.camelize, **attributes).tap do |record|
      record.id = id
      record.define_singleton_method(:form_fields) { [] }
    end
  end

  def catalog(templates: [], admin: false, permitted_keys: [])
    relation = Minitest::Mock.new
    relation.expect(:includes, templates, [:form_fields])

    Forms::Template.stub(:active, relation) do
      yield FormCatalog.new(admin: admin, permitted_keys: permitted_keys)
    end
  end

  test 'an admin sees every legacy form' do
    catalog(admin: true) do |subject|
      assert_equal FormCatalog::LEGACY_FORMS.map { |form| form[:name] }.sort,
                   subject.forms.map(&:first)
    end
  end

  test 'a non-admin sees only the legacy forms their permissions name' do
    catalog(permitted_keys: %w[leave_of_absence]) do |subject|
      assert_equal ['Leave of Absence'], subject.forms.map(&:first)
    end
  end

  test 'a non-admin with no permissions sees nothing' do
    catalog(permitted_keys: []) do |subject|
      assert_empty subject.forms
    end
  end

  test 'a template is offered by its record id, not by its name' do
    rows = [template(id: 42, name: 'Bike Locker', file_name: 'bike_locker_form')]

    catalog(templates: rows, permitted_keys: %w[42]) do |subject|
      assert_equal ['Bike Locker'], subject.forms.map(&:first)
    end

    catalog(templates: rows, permitted_keys: %w[bike_locker]) do |subject|
      assert_empty subject.forms
    end
  end

  test 'a template whose route does not exist is left out rather than linked' do
    rows = [template(id: 7, name: 'Nowhere', file_name: 'no_such_thing_at_all')]

    catalog(templates: rows, admin: true) do |subject|
      assert_not_includes subject.forms.map(&:first), 'Nowhere'
    end
  end

  test 'forms come back alphabetical, whatever order they were found in' do
    rows = [template(id: 1, name: 'Zebra Form', file_name: 'bike_locker_form'),
            template(id: 2, name: 'Aardvark Form', file_name: 'gym_locker_form')]

    catalog(templates: rows, admin: true) do |subject|
      names = subject.forms.map(&:first)

      assert_equal names.sort, names
    end
  end

  test 'a legacy form is not listed twice when a template shares its name' do
    rows = [template(id: 3, name: 'Leave of Absence', file_name: 'bike_locker_form')]

    catalog(templates: rows, admin: true) do |subject|
      names = subject.forms.map(&:first)

      assert_equal 1, names.count('Leave of Absence')
    end
  end

  test 'search data carries what the browser matches on' do
    rows = [template(id: 8, name: 'Bike Locker', file_name: 'bike_locker_form',
                     form_number: 'PB-12', description: 'Request a locker')]

    catalog(templates: rows, admin: true) do |subject|
      data = subject.search_data('Bike Locker')

      assert_equal 'PB-12', data[:number]
      assert_equal 'Request a locker', data[:description]
    end
  end

  test 'a legacy form with no template row still answers with blank metadata' do
    catalog(admin: true) do |subject|
      assert_equal({ fields: '', tags: '', number: '', description: '' },
                   subject.search_data('Leave of Absence'))
    end
  end

  test 'the finder is built from the templates actually offered' do
    rows = [template(id: 4, name: 'Bike Locker', file_name: 'bike_locker_form', agency_id: 'HCA'),
            template(id: 5, name: 'Gym Locker', file_name: 'gym_locker_form', agency_id: 'PWA')]

    catalog(templates: rows, permitted_keys: %w[4]) do |subject|
      assert_equal ['Bike Locker'], subject.finder.templates.map(&:name)
    end
  end
end
