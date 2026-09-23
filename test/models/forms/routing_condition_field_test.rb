# frozen_string_literal: true

require 'test_helper'

module Forms
  class RoutingConditionFieldTest < ActiveSupport::TestCase
    test 'the parking template offers per-vehicle permit types to routing conditions' do
      field = Template.new(class_name: 'ParkingLotSubmission').routing_condition_fields.sole

      assert_equal 'permit_types', field.field_name
      assert_equal 'dropdown', field.field_type
      assert_includes field.dropdown_values, 'R Lot'
    end

    test 'a template whose model offers none, or that has no model, has no extra fields' do
      assert_empty Template.new(class_name: 'BikeLockerForm').routing_condition_fields
      assert_empty Template.new(class_name: 'NoSuchForm').routing_condition_fields
      assert_empty Template.new(class_name: 'Kernel').routing_condition_fields
    end

    test 'a step condition resolves a condition-only field for its label' do
      step = TemplateRoutingStep.new(form_template: Template.new(class_name: 'ParkingLotSubmission'),
                                     condition_field_name: 'permit_types',
                                     condition_operator: 'equals', condition_value: 'R Lot')

      assert_equal 'Only if "Permit Type (any vehicle)" = "R Lot"', step.condition_label
    end

    test 'equals matches when any vehicle requests the permit type' do
      step = r_lot_step('equals')

      assert step.matches?(submission_with(%w[Carpool], ['R Lot', 'Courier']))
      assert_not step.matches?(submission_with(%w[Carpool], %w[Courier]))
      assert_not step.matches?(submission_with)
    end

    test 'not_equals matches only when no vehicle requests the permit type' do
      step = r_lot_step('not_equals')

      assert step.matches?(submission_with(%w[Carpool]))
      assert_not step.matches?(submission_with(%w[Carpool], ['R Lot']))
    end

    test 'a vehicle row being removed does not count toward the condition' do
      submission = submission_with(['R Lot'])
      submission.parking_lot_vehicles.first.mark_for_destruction

      assert_not r_lot_step('equals').matches?(submission)
    end

    test 'scalar conditions still compare the whole value' do
      step = TemplateRoutingStep.new(condition_field_name: 'unit', condition_operator: 'equals',
                                     condition_value: '4661')

      assert step.matches?(ParkingLotSubmission.new(unit: '4661'))
      assert_not step.matches?(ParkingLotSubmission.new(unit: '46611'))
    end

    private

    def r_lot_step(operator)
      TemplateRoutingStep.new(condition_field_name: 'permit_types', condition_operator: operator,
                              condition_value: 'R Lot')
    end

    def submission_with(*vehicle_permit_types)
      ParkingLotSubmission.new.tap do |submission|
        vehicle_permit_types.each { |types| submission.parking_lot_vehicles.build(permit_type: types) }
      end
    end
  end
end
