# frozen_string_literal: true

# app/controllers/concerns/osha_org_filterable.rb
#
# Shared Agency → Division → Department → Unit filtering for the OSHA 300
# portal (300 Log and 300A Summary). Both screens read the org filter from
# the same top-level params, apply it through OshaReport.org_filtered, and
# render the same cascading select partial. A blank value at any level means
# "all" for that level.
module OshaOrgFilterable
  extend ActiveSupport::Concern

  included do
    helper_method :osha_org_filters
  end

  private

  # Present org filter values, keyed for OshaReport.org_filtered.
  def osha_org_filters
    @osha_org_filters ||= {
      agency: params[:agency].presence,
      division: params[:division].presence,
      department: params[:department].presence,
      unit: params[:unit].presence
    }.compact
  end

  # Build the sticky, cascading option lists for the filter selects. Each
  # child list is scoped to the currently selected parent, mirroring the
  # OSHA report form so a reload shows the right drilled-down state.
  def load_osha_org_filter_options
    agency_id     = params[:agency].presence
    division_id   = params[:division].presence
    department_id = params[:department].presence

    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options = agency_id ? Division.where(agency_id: agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division_id ? Department.where(division_id: division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options = if department_id
                      Unit.where(department_id: department_id)
                          .order(:unit_id)
                          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                    else
                      []
                    end
  end
end
