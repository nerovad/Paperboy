# frozen_string_literal: true

# Search over submitted forms — what the Submissions list applies, and the org
# window a visibility grant opens onto it.
#
# Every filter is read straight from the request's `filter_` params, so a
# search is always reproducible from its URL and can be bookmarked or saved.
# The list's own dropdowns are single-value; a caller may send arrays for the
# same params, which every consumer handles (see Filterable#apply_filters).
#
# The sidebar's Advanced Search is a different question entirely — it narrows
# the list of blank forms you can fill out, and belongs to FormFinder.
#
#   search = FormSearch.new(params)
#   scope  = search.apply_org(LeaveOfAbsenceForm, scope)   # SQL narrowing
#   search.include_form_type?("Leave of Absence")          # skip whole tables
#
# Org narrowing happens in SQL because every form table carries its own
# agency/division/department/unit codes, captured when the form was submitted —
# so a search finds where a form *was* filed, not where its submitter sits now.
class FormSearch
  # Agency → Division → Department → Unit, outermost first. Each level is a
  # column on the form's own table holding the GSABSS code (`HCA`, not
  # "Health Care Agency").
  ORG_LEVELS = %i[agency division department unit].freeze

  attr_reader :params

  def initialize(params = {})
    raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    @params = raw.with_indifferent_access
  end

  def agency = params[:filter_agency].to_s.strip

  def division = params[:filter_division].to_s.strip

  def department = params[:filter_department].to_s.strip

  def unit = params[:filter_unit].to_s.strip

  # Only the levels actually chosen, outermost first. A level left blank means
  # "all", and picking a deep level without its parents is still a valid
  # search — unit codes are unique on their own.
  def org_filters
    ORG_LEVELS.index_with { |level| public_send(level) }.select { |_, value| value.present? }
  end

  def form_types = list(:filter_type)

  def statuses = list(:filter_status)

  def categories = list(:filter_category)

  # Whether this form type is in play at all. Lets the Submissions loaders skip
  # whole tables rather than loading them to discard the rows.
  def include_form_type?(name)
    form_types.empty? || form_types.include?(name.to_s)
  end

  # SQL-level org narrowing for one form model. A model missing a column the
  # search asked about can't answer the question, so it contributes nothing
  # rather than every row — "forms filed in HCA" must not include forms whose
  # agency was never recorded.
  def apply_org(model_class, scope)
    org_filters.each do |level, value|
      return model_class.none unless model_class.column_names.include?(level.to_s)

      scope = scope.where(level => level == :agency ? agency_variants(value) : value)
    end
    scope
  end

  # True when anything beyond the plain list is set. The Submissions list uses
  # this to decide whether to report the search above its results.
  def advanced?
    org_filters.any? || form_types.any? || statuses.any? || categories.any?
  end

  alias any? advanced?

  # One chip per active criterion, shown above the results.
  def summary
    chips = org_filters.map { |level, value| "#{level_label(level)}: #{org_label(level, value)}" }
    chips << "Form: #{form_types.join(', ')}" if form_types.any?
    chips << "Status: #{statuses.join(', ')}" if statuses.any?
    chips << "Category: #{categories.join(', ')}" if categories.any?
    chips
  end

  # Display label for an org level, in the vocabulary of the selected agency —
  # HCA calls a division a department and vice versa (see OrgLabels).
  def level_label(level)
    OrgLabels.label(level, agency)
  end

  # --- Option lists for the org cascade --------------------------------------
  # Class methods because the cascade partial renders wherever a screen needs
  # to narrow to part of the county, under whichever controller drew it.

  def self.agency_options
    Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)
  end

  def self.division_options(agency)
    return [] if agency.blank?

    Coa::Division.where(agency_id: agency).order(:long_name).pluck(:long_name, :division_id)
  end

  def self.department_options(division)
    return [] if division.blank?

    Coa::Department.where(division_id: division).order(:long_name).pluck(:long_name, :department_id)
  end

  def self.unit_options(department)
    return [] if department.blank?

    Coa::Unit.where(department_id: department).order(:unit_id).map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
  end

  private

  def list(key)
    Array(params[key]).map { |value| value.to_s.strip }.compact_blank
  end

  # `Employees.agency` carries a four-character variant ("HCAV") of the
  # three-character id the org tables use, and a form that prefilled from the
  # employee rather than the org walk can hold either. Match both spellings.
  def agency_variants(code)
    [code, "#{code}V"].uniq
  end

  def org_label(level, value)
    case level
    when :agency then Coa::Agency.where(agency_id: value).pick(:long_name) || value
    when :division then Coa::Division.where(division_id: value).pick(:long_name) || value
    when :department then Coa::Department.where(department_id: value).pick(:long_name) || value
    else Coa::Unit.where(unit_id: value).pick(:long_name)&.then { |name| "#{value} - #{name}" } || value
    end
  end
end
