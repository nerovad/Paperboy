# frozen_string_literal: true

require 'test_helper'

# The catalogue behind the CIR form's "Where: Location" dropdown. It is data
# rather than labels — every report already filed carries the name verbatim —
# so the rules here are about not breaking that.
class CriticalInformationLocationTest < ActiveSupport::TestCase
  A_NAME = 'TEST CITY-1 FIRST ST.'

  setup do
    CriticalInformationAuthorization.delete_all
    CriticalInformationLocation.delete_all
  end

  test 'a location needs a name' do
    subject = CriticalInformationLocation.new(name: '')

    assert_not subject.valid?
    assert_includes subject.errors[:name], "can't be blank"
  end

  test 'the same site cannot be added twice, in any casing' do
    CriticalInformationLocation.create!(name: A_NAME)

    duplicate = CriticalInformationLocation.new(name: A_NAME.downcase)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], 'is already on the form'
  end

  test 'the dropdown lists every site in name order' do
    %w[CCC AAA BBB].each { |n| CriticalInformationLocation.create!(name: n) }

    assert_equal %w[AAA BBB CCC], CriticalInformationLocation.names
    assert_equal [%w[AAA AAA], %w[BBB BBB], %w[CCC CCC]], CriticalInformationLocation.options
  end

  test 'a site knows the manager covering it, if anyone does' do
    site = CriticalInformationLocation.create!(name: A_NAME)

    assert_nil site.authorization

    CriticalInformationAuthorization.stub(:manager_in_agency?, true) do
      CriticalInformationAuthorization.create!(location: A_NAME, employee_id: '999001')
    end

    assert_equal '999001', site.authorization.employee_id
  end

  test 'exists_named? is what the authorization validation asks' do
    CriticalInformationLocation.create!(name: A_NAME)

    assert CriticalInformationLocation.exists_named?(A_NAME)
    assert_not CriticalInformationLocation.exists_named?('NOWHERE-1 MADE UP ST.')
    assert_not CriticalInformationLocation.exists_named?(nil)
  end
end
