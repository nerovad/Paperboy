# frozen_string_literal: true

require 'test_helper'

# Which incident manager covers each site on the Critical Information Reporting
# form. This replaced a hardcoded fuzzy address matcher, so the tests care most
# about the two things that used to go wrong: a location matching nobody, and a
# location matching more than one manager.
class CriticalInformationAuthorizationTest < ActiveSupport::TestCase
  A_LOCATION       = 'TEST CITY-1 FIRST ST.'
  ANOTHER_LOCATION = 'TEST CITY-2 SECOND ST.'

  # Both tables ship seeded — the catalogue, and the mapping migrated out of the
  # old router. These tests are about the rules, not that data, so start from an
  # empty pair with two sites of their own. Transactional tests roll it back.
  setup do
    CriticalInformationAuthorization.delete_all
    CriticalInformationLocation.delete_all
    [A_LOCATION, ANOTHER_LOCATION].each { |name| CriticalInformationLocation.create!(name: name) }
  end

  def build(**attributes)
    CriticalInformationAuthorization.new(location: A_LOCATION, employee_id: '999001', **attributes)
  end

  # Whether an employee is General Services Agency staff is a live GSABSS
  # lookup. These tests are about the location rules, so pin the answer rather
  # than depending on who happens to be in the agency.
  def with_candidates(ids, &block)
    accept = ->(employee_id) { ids.include?(employee_id.to_s) }
    CriticalInformationAuthorization.stub(:manager_in_agency?, accept, &block)
  end

  test 'a location and a manager are both required' do
    with_candidates(['999001']) do
      subject = build(location: '', employee_id: '')

      assert_not subject.valid?
      assert_includes subject.errors[:location], "can't be blank"
      assert_includes subject.errors[:employee_id], "can't be blank"
    end
  end

  test 'the location has to be one the form actually offers' do
    with_candidates(['999001']) do
      subject = build(location: 'NOWHERE-1 MADE UP ST.')

      assert_not subject.valid?
      assert_includes subject.errors[:location],
                      'is not a location on the Critical Information Reporting form'
    end
  end

  test 'a manager has to be a General Services Agency employee' do
    with_candidates(['999002']) do
      subject = build(employee_id: '999001')

      assert_not subject.valid?
      assert_includes subject.errors[:employee_id], 'is not a General Services Agency employee'
    end
  end

  test 'a location can only have one incident manager' do
    with_candidates(%w[999001 999002]) do
      build(location: A_LOCATION, employee_id: '999001').save!

      second = build(location: A_LOCATION, employee_id: '999002')

      assert_not second.valid?
      assert_includes second.errors[:location], 'already has an incident manager'
    end
  end

  test 'an existing row stays editable after its manager leaves the agency' do
    subject = with_candidates(['999001']) { build(employee_id: '999001').tap(&:save!) }

    with_candidates(['999002']) do
      assert subject.valid?, 'unchanged manager should not be re-checked against the agency'
      assert subject.update(location: ANOTHER_LOCATION)
    end
  end

  test 'a report routes to the manager holding its exact location' do
    with_candidates(['999001']) { build(location: A_LOCATION, employee_id: '999001').save! }

    assert_equal '999001', CriticalInformationAuthorization.manager_id_for_location(A_LOCATION)
  end

  test 'an unassigned location routes to nobody rather than to a near match' do
    assert_nil CriticalInformationAuthorization.manager_id_for_location(ANOTHER_LOCATION)
    assert_nil CriticalInformationAuthorization.manager_id_for_location('')
    assert_nil CriticalInformationAuthorization.manager_id_for_location(nil)
  end

  test 'routing tolerates case and punctuation drift in a stored location' do
    with_candidates(['999001']) { build(location: A_LOCATION, employee_id: '999001').save! }

    drifted = A_LOCATION.downcase.delete('.')

    assert_equal '999001', CriticalInformationAuthorization.manager_id_for_location(drifted)
  end

  test 'deleting the site a manager covers is what removes the authorization' do
    with_candidates(['999001']) { build(location: A_LOCATION, employee_id: '999001').save! }

    CriticalInformationLocation.find_by(name: A_LOCATION).destroy!

    # The row survives on its own — the console cascades the delete, and until
    # then the site shows as "no longer on the form" rather than vanishing.
    assert CriticalInformationAuthorization.exists?(location: A_LOCATION)
    assert_not_includes CriticalInformationLocation.names, A_LOCATION
  end

  test 'normalizing keeps addresses apart instead of guessing at abbreviations' do
    normalize = CriticalInformationAuthorization.method(:normalize)

    assert_equal normalize.call('VENTURA-800 S. VICTORIA AVE'), normalize.call('ventura - 800 s victoria ave')
    assert_not_equal normalize.call('VENTURA-800 S VICTORIA AVE'), normalize.call('VENTURA-800 N VICTORIA AVE')
  end

  test 'the inbox filter narrows to the locations a manager covers, or nothing' do
    with_candidates(['999001']) { build(location: A_LOCATION, employee_id: '999001').save! }

    assert_equal({ location: [A_LOCATION] },
                 CriticalInformationAuthorization.inbox_conditions_for(['999001']))
    assert_nil CriticalInformationAuthorization.inbox_conditions_for(['999002'])
    assert_nil CriticalInformationAuthorization.inbox_conditions_for([])
  end
end
