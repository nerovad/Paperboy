# frozen_string_literal: true

require 'test_helper'

# FormLibrary narrows the forms a FormCatalog offers by what the request asks
# for. The catalog here is a stand-in handing over in-memory templates: the
# ACL is FormCatalog's own business and has its own tests, and what matters
# in this file is which of the forms it let through survive a search.
class FormLibraryTest < ActiveSupport::TestCase
  StubCatalog = Struct.new(:templates) do
    def forms = templates.map { |template| [template.name, "/#{template.name.parameterize}/new"] }

    def template_for(name) = templates.find { |template| template.name == name }

    def key_for(name) = name.parameterize

    def finder = FormFinder.new(templates)
  end

  def template(name, **attributes)
    Forms::Template.new(name: name, **attributes).tap do |record|
      record.define_singleton_method(:form_fields) { [] }
    end
  end

  # A collection as the library reads one: an id, a name, and the keys of the
  # forms it names. The stub catalog keys a form by its parameterized name.
  StubCollection = Struct.new(:id, :name, :description, :form_keys) do
    def haystack = [name, description].join(' ').downcase
  end

  def collection(id, name, *form_keys, description: '')
    StubCollection.new(id, name, description, form_keys)
  end

  def library(collections: [], **params)
    templates = [
      template('Bike Locker', form_number: 'GSA-101', form_type: 'Request', agency_id: 'GSA',
                              tags: 'transportation,Security', description: 'Reserve a bike locker'),
      template('Safety Reporting', form_type: 'Report', agency_id: 'HCA', tags: 'safety,hca'),
      template('Telework Log', form_type: 'Log', tags: 'remote')
    ]
    FormLibrary.new(StubCatalog.new(templates), params, collections: collections)
  end

  def names(subject) = subject.results.map(&:name)

  test 'with nothing asked for, every form is listed' do
    assert_equal ['Bike Locker', 'Safety Reporting', 'Telework Log'], names(library)
    assert_not library.filtered?
  end

  test 'the search box matches name, number, description and tags, whatever the case' do
    assert_equal ['Bike Locker'], names(library(q: 'gsa-101'))
    assert_equal ['Bike Locker'], names(library(q: 'RESERVE'))
    assert_equal ['Safety Reporting'], names(library(q: 'hca'))
  end

  test 'every word typed has to appear on the form' do
    assert_equal ['Bike Locker'], names(library(q: 'bike security'))
    assert_empty names(library(q: 'bike safety'))
  end

  test 'a form tied to no org drops out once an org is chosen' do
    assert_equal ['Bike Locker'], names(library(filter_agency: 'GSA'))
  end

  test 'any one of the ticked types or tags will do' do
    assert_equal ['Bike Locker', 'Telework Log'], names(library(type: %w[Request Log]))
    assert_equal ['Bike Locker', 'Safety Reporting'], names(library(tag: %w[security safety]))
  end

  test 'a collection lists the forms it names' do
    groups = [collection(1, 'Commuting', 'bike-locker', 'telework-log')]

    assert_equal ['Bike Locker', 'Telework Log'], names(library(collection: '1', collections: groups))
  end

  test 'a form the viewer may not open is not shown by a collection that names it' do
    # 'parking-permit' is not among the forms the catalog let through, so the
    # collection shows the one form of its two that this viewer can open.
    groups = [collection(1, 'Parking', 'bike-locker', 'parking-permit')]
    subject = library(collection: '1', collections: groups)

    assert_equal ['Bike Locker'], names(subject)
    assert_equal [1], subject.collections.map(&:last)
  end

  test 'a search inside a collection stays inside it' do
    groups = [collection(1, 'Commuting', 'bike-locker')]
    subject = library(collection: '1', q: 'safety', collections: groups)

    assert_equal 1, subject.collection.id
    assert_empty names(subject)
  end

  test 'a collection holding none of the viewer\'s forms is not offered and cannot be browsed' do
    groups = [collection(1, 'Parking', 'parking-permit'), collection(2, 'Commuting', 'bike-locker')]
    subject = library(collection: '1', collections: groups)

    assert_equal([2], subject.collections.map { |group, _| group.id })
    assert_nil subject.collection
  end

  test 'a manager is offered every collection, an empty one included' do
    groups = [collection(1, 'Brand new')]
    subject = FormLibrary.new(StubCatalog.new([]), { collection: '1' }, collections: groups, manager: true)

    assert_equal([[1, 0]], subject.collections.map { |group, count| [group.id, count] })
    assert_equal 1, subject.collection.id
  end

  test 'the search box finds a collection by its name or description' do
    groups = [collection(1, 'Fleet', 'bike-locker'),
              collection(2, 'Clinics', 'safety-reporting', description: 'Safety and risk')]

    assert_equal([1], library(q: 'FLEET', collections: groups).matching_collections.map { |group, _| group.id })
    assert_equal([2], library(q: 'risk', collections: groups).matching_collections.map { |group, _| group.id })
    assert_empty library(q: 'payroll', collections: groups).matching_collections
  end

  test 'with nothing typed every collection is offered, whatever the facets say' do
    groups = [collection(1, 'Fleet', 'bike-locker'), collection(2, 'Clinics', 'safety-reporting')]

    assert_equal 2, library(type: %w[Log], collections: groups).matching_collections.size
  end
end
