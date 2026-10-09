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

    def finder = FormFinder.new(templates)
  end

  def template(name, **attributes)
    Forms::Template.new(name: name, **attributes).tap do |record|
      record.define_singleton_method(:form_fields) { [] }
    end
  end

  def collection(key, **rules)
    FormLibrary::Collection.new(key, key.titleize, '', Array(rules[:tags]),
                                Array(rules[:agencies]), Array(rules[:forms]))
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

  test 'a collection takes a form by tag, by issuing agency or by name' do
    groups = [collection('mixed', tags: %w[security], agencies: %w[HCA], forms: ['Telework Log'])]

    assert_equal 3, library(collection: 'mixed', collections: groups).results.size
  end

  test 'a search inside a collection stays inside it' do
    groups = [collection('gsa', agencies: %w[GSA])]
    subject = library(collection: 'gsa', q: 'safety', collections: groups)

    assert_equal 'gsa', subject.collection.key
    assert_empty names(subject)
  end

  test 'a collection the viewer has no forms in is not offered and cannot be browsed' do
    groups = [collection('empty', tags: %w[nothing]), collection('gsa', agencies: %w[GSA])]
    subject = library(collection: 'empty', collections: groups)

    offered = subject.collections.map { |group, count| [group.key, count] }

    assert_equal [['gsa', 1]], offered
    assert_nil subject.collection
  end

  test 'the collections file loads and every entry has a name and a rule' do
    FormLibrary.defined_collections.each do |group|
      assert_predicate group.name, :present?
      assert_predicate group.tags + group.agencies + group.forms, :any?, "#{group.key} matches nothing"
    end
  end
end
