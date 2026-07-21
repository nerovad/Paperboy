# frozen_string_literal: true

# Per-agency display names for the middle two levels of the county org
# hierarchy (Agency → Division → Department → Unit).
#
# The Health Care Agency's own vocabulary is the reverse of GSABSS's: what the
# database stores as a *division* HCA calls a department, and what it stores as
# a *department* HCA calls a division. This swaps only the labels — values stay
# in the columns they have always been in, so queries, routing and exports are
# unaffected.
#
# Submissions store the three-character `agencies.agency_id` ("HCA"), while
# `Employees.agency` carries a four-character variant ("HCAV"), so both spellings
# count as HCA.
module OrgLabels
  SWAPPED_AGENCY_IDS = %w[HCA HCAV].freeze

  # Some tables denormalize the agency to its display name rather than its id
  # (P-Card inventory rows, for one), so the long name has to match too.
  SWAPPED_AGENCY_NAMES = ['HEALTH CARE AGENCY'].freeze

  CANONICAL = { agency: 'Agency', division: 'Division',
                department: 'Department', unit: 'Unit' }.freeze

  # Only the two middle levels swap; agency and unit mean the same thing to
  # everyone.
  SWAPPED = CANONICAL.merge(division: 'Department', department: 'Division').freeze

  module_function

  # Whether this agency uses the reversed vocabulary. Accepts an agency id
  # ("HCA"), the Employees variant ("HCAV") or the display name.
  def swapped?(agency)
    key = agency.to_s.strip.upcase
    SWAPPED_AGENCY_IDS.include?(key) || SWAPPED_AGENCY_NAMES.include?(key)
  end

  # Display label for an org level as the given agency names it.
  def label(level, agency)
    table = swapped?(agency) ? SWAPPED : CANONICAL
    table.fetch(level.to_sym, level.to_s.titleize)
  end

  # The label map handed to the browser so the org cascade can relabel itself
  # when the user picks a different agency mid-form.
  def js_config
    { swappedAgencyIds: SWAPPED_AGENCY_IDS, canonical: CANONICAL, swapped: SWAPPED }
  end
end
