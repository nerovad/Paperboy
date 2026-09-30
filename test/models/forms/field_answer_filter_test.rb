# frozen_string_literal: true

require 'test_helper'

# A custom lookup's category filter can follow another field's answer (City
# narrowing an address list) instead of holding a fixed value.
class FormsFieldAnswerFilterTest < ActiveSupport::TestCase
  def lookup_field(filters)
    template = Forms::Template.new(class_name: 'FleetVehicleGaragingForm', name: 'Fleet')
    Forms::Field.new(form_template: template, field_name: 'location', field_type: 'dropdown',
                     options: { 'custom_lookup' => { 'database' => 'gsabss', 'table' => 'fleet_locations',
                                                     'column' => 'Address', 'category_filters' => filters } })
  end

  def generator = FormTemplatesController.new

  test 'keeps a filter that follows a field apart from a fixed one' do
    field = lookup_field([{ 'column' => 'City', 'field' => 'city' }, { 'column' => 'State', 'value' => 'CA' }])

    assert_equal [{ 'column' => 'City', 'field' => 'city' }, { 'column' => 'State', 'value' => 'CA' }],
                 field.custom_lookup_category_filters
    assert_equal ['city'], field.custom_lookup_answer_filter_fields
  end

  test 'a generated view hands a filtered lookup the record and wires the reload' do
    field = lookup_field([{ 'column' => 'City', 'field' => 'city' }])

    assert_equal 'FormLookup.options_for("FleetVehicleGaragingForm", "location", @fleet_vehicle_garaging_form)',
                 generator.send(:field_options_expr, field)
    attrs = generator.send(:searchable_select_attrs_str, field, ['class: "form-control"'])

    assert_includes attrs, 'controller: "searchable-select lookup-filter"'
    assert_includes attrs, 'lookup_filter_sources_value: "[\"city\"]"'
  end

  test 'an unfiltered lookup is generated as before' do
    field = lookup_field([{ 'column' => 'State', 'value' => 'CA' }])

    assert_equal 'FormLookup.options_for("FleetVehicleGaragingForm", "location")', generator.send(:field_options_expr, field)
    assert_equal 'class: "form-control", data: { controller: "searchable-select" }',
                 generator.send(:searchable_select_attrs_str, field, ['class: "form-control"'])
  end

  test 'the builder stores "field:" values as a field filter' do
    params = ActionController::Parameters.new(custom_category_columns: %w[City State],
                                              custom_category_values: %w[field:city CA])

    assert_equal [{ 'column' => 'City', 'field' => 'city' }, { 'column' => 'State', 'value' => 'CA' }],
                 generator.send(:build_custom_lookup, params)['category_filters']
  end

  test 'reads an answer from a record attribute or a Hash, never a method' do
    record = FleetVehicle.new(color: 'WHITE')

    assert_equal 'WHITE', FormLookup.send(:answer_for, record, 'color')
    assert_equal 'OJAI', FormLookup.send(:answer_for, { 'city' => 'OJAI' }, 'city')
    assert_nil FormLookup.send(:answer_for, record, 'vehicle_label')
    assert_nil FormLookup.send(:answer_for, record, 'destroy')
    assert_nil FormLookup.send(:answer_for, nil, 'city')
  end
end
