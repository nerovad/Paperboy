# frozen_string_literal: true

require 'test_helper'

# FleetVehicle is the fleet master; a garaging form names one vehicle already
# on it, and submitting the form copies its answers onto that vehicle.
class FleetVehicleGaragingFormTest < ActiveSupport::TestCase
  setup do
    @vehicle = FleetVehicle.create!(vehicle_number: '4763', make: 'CHEV', model: 'VAN', year: 2014,
                                    take_home: 'No', assigned_to: 'Irma Hernandez',
                                    garaging_location: '800 S. Victoria Ave',
                                    secondary_garaging_location: '646 County Square Dr')
  end

  def garaging_form(**attrs)
    FleetVehicleGaragingForm.create!({ name: 'Jane Smith', email: 'jane.smith@example.com',
                                       vehicle_number: '4763' }.merge(attrs))
  end

  test 'names a vehicle on the fleet list' do
    form = FleetVehicleGaragingForm.new(name: 'Jane Smith', email: 'jane.smith@example.com', vehicle_number: '9999')

    assert_not form.valid?
    assert_includes form.errors[:vehicle_number], 'is not on the fleet list'

    form.vehicle_number = nil
    assert_not form.valid?
  end

  test 'submitting copies the answers onto the vehicle' do
    form = garaging_form(assign_to: 'Jane Smith', is_this_a_take_home_vehicle: 'Yes', location: 'Other',
                         other_location: '1 Main St', do_you_have_a_secondary_location: 'No')
    @vehicle.reload

    assert_equal 'Jane Smith', @vehicle.assigned_to
    assert_equal 'Yes', @vehicle.take_home
    assert_equal '1 Main St', @vehicle.garaging_location
    assert_nil @vehicle.secondary_garaging_location
    assert_equal form, @vehicle.fleet_vehicle_garaging_form
    assert_equal 1, FleetVehicle.where(vehicle_number: '4763').count
  end

  test 'Other assigns the vehicle to the typed name' do
    garaging_form(assign_to: 'Other', other_assignee: 'Pat Contractor')

    assert_equal 'Pat Contractor', @vehicle.reload.assigned_to
  end

  test 'the vehicle details come from the fleet list, not the request' do
    form = garaging_form(year: 1999, make: 'FORD', model: 'F150', vehicle_assigned_to: 'Someone Else',
                         last_known_location: 'Nowhere', location: 'Other', other_location: '1 Main St')

    assert_equal [2014, 'CHEV', 'VAN'], [form.year, form.make, form.model]
    assert_equal 'Irma Hernandez', form.vehicle_assigned_to
    assert_equal '800 S. Victoria Ave', form.last_known_location
  end

  test 'a blank answer keeps what is on file' do
    garaging_form
    @vehicle.reload

    assert_equal 'Irma Hernandez', @vehicle.assigned_to
    assert_equal 'No', @vehicle.take_home
    assert_equal '800 S. Victoria Ave', @vehicle.garaging_location
    assert_equal '646 County Square Dr', @vehicle.secondary_garaging_location
  end

  test 'editing the latest submission updates the vehicle, an older one does not' do
    older = garaging_form(assign_to: 'Jane Smith')
    latest = garaging_form(assign_to: 'Pat Contractor')

    older.update!(assign_to: 'Someone Else')
    assert_equal 'Pat Contractor', @vehicle.reload.assigned_to

    latest.update!(assign_to: 'Chris Driver')
    assert_equal 'Chris Driver', @vehicle.reload.assigned_to
  end
end
