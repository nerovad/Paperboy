# frozen_string_literal: true

require 'test_helper'

class AgencyTest < ActiveSupport::TestCase
  # agencies.agency_id is nvarchar(3). With prepared statements on -- staging
  # and production, but not development -- SQL Server casts the bound
  # parameter to the column type before comparing, so a lookup for a
  # four-character personnel id matches the three-character row. normalize_id
  # must not read that as a hit, or the org chain keeps the 'V' suffix and
  # every org-level ACL grant is skipped for that employee.
  test 'trims the personnel-system suffix on a connection that truncates parameters' do
    Coa::Agency.stub(:where, truncating_lookup(%w[GSA])) do
      assert_equal 'GSA', Coa::Agency.normalize_id('GSAV')
    end
  end

  test 'trims the personnel-system suffix on a connection that compares exactly' do
    Coa::Agency.stub(:where, exact_lookup(%w[GSA])) do
      assert_equal 'GSA', Coa::Agency.normalize_id('GSAV')
    end
  end

  test 'keeps an id the agencies table holds' do
    Coa::Agency.stub(:where, truncating_lookup(%w[GSA])) do
      assert_equal 'GSA', Coa::Agency.normalize_id('gsa ')
    end
  end

  # Nothing to trim to, so the code is returned as given rather than mangled.
  test 'keeps an unknown id' do
    Coa::Agency.stub(:where, exact_lookup(%w[GSA])) do
      assert_equal 'FPD', Coa::Agency.normalize_id('FPD')
      assert_equal 'FPDV', Coa::Agency.normalize_id('FPDV')
    end
  end

  test 'is nil for a blank code' do
    assert_nil Coa::Agency.normalize_id(nil)
    assert_nil Coa::Agency.normalize_id('   ')
  end

  private

  # Stands in for SQL Server with prepared statements on: the parameter is cut
  # to the column width before the comparison, so 'GSAV' finds the 'GSA' row.
  def truncating_lookup(ids)
    ->(conditions) { relation(ids, conditions[:agency_id].to_s[0, 3]) }
  end

  def exact_lookup(ids)
    ->(conditions) { relation(ids, conditions[:agency_id].to_s) }
  end

  # A stand-in for the relation, answering only the +pick+ normalize_id sends.
  def relation(ids, wanted)
    found = ids.find { |id| id == wanted }
    Object.new.tap do |scope|
      scope.define_singleton_method(:pick) { |_column| found }
    end
  end
end
