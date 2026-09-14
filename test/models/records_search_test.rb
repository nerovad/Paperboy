# frozen_string_literal: true

require 'test_helper'

class RecordsSearchTest < ActiveSupport::TestCase
  def pcard_table = RegistryTable.find('pcard')
  def fleet_table = RegistryTable.find('fleet')

  def vehicle(owner:, plate: 'ABC123')
    form = FleetVehicleGaragingForm.new(name: owner)
    FleetVehicle.new(license_plate: plate, fleet_vehicle_garaging_form: form)
  end

  test 'searches stored columns' do
    columns = RecordsSearch.searchable_columns(pcard_table)

    assert_includes columns, 'last_name'
    assert_includes columns, 'agency'
  end

  test 'searches derived columns' do
    # masked_card_number and owner_name are methods, not columns, but they are
    # cells on the table, so a search has to reach them.
    assert_includes RecordsSearch.searchable_columns(pcard_table), 'masked_card_number'
    assert_includes RecordsSearch.searchable_columns(fleet_table), 'owner_name'
  end

  test 'skips encrypted columns' do
    # card_number decrypts on read; searching it would let a query probe it.
    assert_not_includes RecordsSearch.searchable_columns(pcard_table), 'card_number'
  end

  test 'a blank query keeps every row' do
    rows = [vehicle(owner: 'Jane Smith'), vehicle(owner: 'Raj Patel')]

    assert_equal rows, RecordsSearch.apply(fleet_table, rows, '   ')
    assert_equal rows, RecordsSearch.apply(fleet_table, rows, nil)
  end

  test 'matches the fleet Assigned To column' do
    smith = vehicle(owner: 'Jane Smith')
    patel = vehicle(owner: 'Raj Patel')

    assert_equal [smith], RecordsSearch.apply(fleet_table, [smith, patel], 'smith')
  end

  test 'matches case-insensitively across any column' do
    smith = vehicle(owner: 'Jane Smith', plate: 'XYZ789')
    patel = vehicle(owner: 'Raj Patel', plate: 'ABC123')

    assert_equal [smith], RecordsSearch.apply(fleet_table, [smith, patel], 'xyz')
  end
end
