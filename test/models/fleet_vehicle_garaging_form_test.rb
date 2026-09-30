# frozen_string_literal: true

require 'test_helper'

# FleetVehicle is the fleet master; a garaging form names one vehicle already
# on it, and submitting the form copies its answers onto that vehicle.
class FleetVehicleGaragingFormTest < ActiveSupport::TestCase
  setup do
    @vehicle = FleetVehicle.create!(vehicle_number: '4763', make: 'CHEV', model: 'VAN', year: 2014,
                                    take_home: 'No', contact_name: 'Irma Hernandez',
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
    form = garaging_form(contact_name: 'Chris Driver', is_this_a_take_home_vehicle: 'Yes', location: 'Other',
                         other_location: '1 Main St', do_you_have_a_secondary_location: 'No')
    @vehicle.reload

    assert_equal 'Chris Driver', @vehicle.contact_name
    assert_equal 'Yes', @vehicle.take_home
    assert_equal '1 Main St', @vehicle.garaging_location
    assert_nil @vehicle.secondary_garaging_location
    assert_equal form, @vehicle.fleet_vehicle_garaging_form
    assert_equal 1, FleetVehicle.where(vehicle_number: '4763').count
  end

  test 'Other makes the typed name the contact' do
    garaging_form(contact_name: 'Other', other_contact: 'Pat Contractor')

    assert_equal 'Pat Contractor', @vehicle.reload.contact_name
  end

  test 'the submitter becomes the vehicle\'s Last Updated By' do
    @vehicle.update_column(:last_updated_by, 'Irma Hernandez')
    form = FleetVehicleGaragingForm.new(vehicle_number: '4763')
    assert_equal 'Irma Hernandez', form.last_updated_by

    garaging_form(name: 'Jane Smith')

    assert_equal 'Jane Smith', @vehicle.reload.last_updated_by
  end

  test 'a Records grid edit names the signed-in user as Last Updated By' do
    Current.user = { 'employee_id' => '1', 'first_name' => 'Raj', 'last_name' => 'Patel' }
    @vehicle.update!(color: 'WHITE')

    assert_equal 'Raj Patel', @vehicle.reload.last_updated_by
  ensure
    Current.reset
  end

  test 'a save with nobody signed in leaves Last Updated By alone' do
    @vehicle.update_column(:last_updated_by, 'Irma Hernandez')
    @vehicle.update!(color: 'WHITE')

    assert_equal 'Irma Hernandez', @vehicle.reload.last_updated_by
  end

  test 'the vehicle details come from the fleet list, not the request' do
    form = garaging_form(year: 1999, make: 'FORD', model: 'F150',
                         last_known_location: 'Nowhere', location: 'Other', other_location: '1 Main St')

    assert_equal [2014, 'CHEV', 'VAN'], [form.year, form.make, form.model]
    assert_equal '800 S. Victoria Ave', form.last_known_location
  end

  test 'a blank answer keeps what is on file' do
    garaging_form
    @vehicle.reload

    assert_equal 'Irma Hernandez', @vehicle.contact_name
    assert_equal 'No', @vehicle.take_home
    assert_equal '800 S. Victoria Ave', @vehicle.garaging_location
    assert_equal '646 County Square Dr', @vehicle.secondary_garaging_location
  end

  test 'editing the latest submission updates the vehicle, an older one does not' do
    older = garaging_form(contact_name: 'Jane Smith')
    latest = garaging_form(contact_name: 'Pat Contractor')

    older.update!(contact_name: 'Someone Else')
    assert_equal 'Pat Contractor', @vehicle.reload.contact_name

    latest.update!(contact_name: 'Chris Driver')
    assert_equal 'Chris Driver', @vehicle.reload.contact_name
  end
end
