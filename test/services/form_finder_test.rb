# frozen_string_literal: true

require 'test_helper'

# FormFinder builds the sidebar's Advanced Search facets from the form
# templates that panel is showing. Templates are built in memory rather than
# saved: the finder only reads their metadata, and the org tables it names
# codes from are shared reference data no test should be writing to.
class FormFinderTest < ActiveSupport::TestCase
  def template(**attributes)
    Forms::Template.new(**attributes)
  end

  test 'the org tree lists each level under the code above it' do
    finder = FormFinder.new([
                              template(agency_id: 'AA1', division_id: 'D1', department_id: 'P1', unit_id: 'U1'),
                              template(agency_id: 'AA1', division_id: 'D2'),
                              template(agency_id: 'BB2', division_id: 'D3')
                            ])
    tree = finder.org_tree

    assert_equal %w[AA1 BB2], tree[:agencies].map(&:last).sort
    assert_equal %w[D1 D2], tree[:divisions]['AA1'].map(&:last).sort
    assert_equal %w[D3], tree[:divisions]['BB2'].map(&:last)
    assert_equal %w[P1], tree[:departments]['D1'].map(&:last)
    assert_equal %w[U1], tree[:units]['P1'].map(&:last)
  end

  test 'a level with nothing under it is absent rather than empty' do
    tree = FormFinder.new([template(agency_id: 'AA1')]).org_tree

    assert_empty tree[:divisions]
    assert_empty tree[:units]
  end

  test 'a code the org tables no longer carry is still offered under its code' do
    # Dropping it would leave every form tagged that way unreachable from the
    # panel, which is worse than a row labelled with a bare code.
    tree = FormFinder.new([template(agency_id: 'ZZ9')]).org_tree

    assert_equal [%w[ZZ9 ZZ9]], tree[:agencies]
  end

  test 'org codes are named from the org tables when they are known' do
    agency = Coa::Agency.order(:agency_id).first
    skip 'no agencies in the reference database' if agency.nil?

    tree = FormFinder.new([template(agency_id: agency.agency_id)]).org_tree

    assert_equal [[agency.long_name, agency.agency_id]], tree[:agencies]
  end

  test 'only the form types actually in use are offered, in the vocabulary order' do
    finder = FormFinder.new([
                              template(form_type: 'Report'),
                              template(form_type: 'Application'),
                              template(form_type: 'Report'),
                              template(form_type: nil)
                            ])

    assert_equal %w[Application Report], finder.form_types
  end

  test 'tags are deduped and ordered without regard to case' do
    finder = FormFinder.new([
                              template(tags: 'Safety, parking'),
                              template(tags: 'Safety, Fleet')
                            ])

    assert_equal %w[Fleet parking Safety], finder.tags
  end

  test 'a set of forms with no metadata offers no facets' do
    assert_not FormFinder.new([template(name: 'Bare')]).any_facets?
    assert FormFinder.new([template(tags: 'safety')]).any_facets?
    assert FormFinder.new([template(form_number: 'HR-101')]).any_facets?
  end

  test 'the org path reads outermost level first' do
    subject = template(agency_id: 'AA1', division_id: 'D1', unit_id: 'U1')

    assert_equal 'AA1 › D1 › U1', FormFinder.new([subject]).org_path(subject)
  end

  test 'a form tied to no organization has no org path' do
    subject = template(name: 'Bare')

    assert_equal '', FormFinder.new([subject]).org_path(subject)
  end
end
