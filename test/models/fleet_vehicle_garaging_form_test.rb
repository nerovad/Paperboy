# frozen_string_literal: true

require 'test_helper'

# FleetVehicle is the fleet master; a garaging form names one vehicle already
# on it, and approving the form copies its answers onto that vehicle.
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

  test 'approval copies the answers onto the vehicle' do
    form = garaging_form(is_this_a_take_home_vehicle: 'Yes', location: 'Other', other_location: '1 Main St',
                         do_you_have_a_secondary_location: 'No')
    form.approved!
    @vehicle.reload

    assert_equal 'Yes', @vehicle.take_home
    assert_equal '1 Main St', @vehicle.garaging_location
    assert_nil @vehicle.secondary_garaging_location
    assert_equal form, @vehicle.fleet_vehicle_garaging_form
  end

  test 'a blank answer keeps what is on file, and Assigned To is never changed' do
    garaging_form(vehicle_assigned_to: 'Someone Else').approved!
    @vehicle.reload

    assert_equal 'No', @vehicle.take_home
    assert_equal '800 S. Victoria Ave', @vehicle.garaging_location
    assert_equal '646 County Square Dr', @vehicle.secondary_garaging_location
    assert_equal 'Irma Hernandez', @vehicle.assigned_to
  end

  test 'nothing changes until the form is approved' do
    form = garaging_form(is_this_a_take_home_vehicle: 'Yes')
    form.denied!

    assert_equal 'No', @vehicle.reload.take_home
  end
end
