# frozen_string_literal: true

# Grants a group (or a single employee) sight of submissions that aren't their
# own, for one form type. Keyed by model class name, so it covers both dynamic
# form-builder forms and legacy hand-written ones like CriticalInformationReporting.
#
# Two things make a grant granular:
#
# * +applies_to+ picks the surfaces it widens. A group that reviews every
#   maintenance request but should not inherit anybody's work queue gets a
#   'submissions' grant; 'both' is the old all-or-nothing behaviour.
# * The four org columns narrow it to submissions filed inside one agency,
#   division, department or unit. All four blank means every submission of the
#   form. Narrowing runs against the org codes on the form's own table — the
#   same columns Advanced Search filters on — so a grant follows where a form
#   *was* filed, not where its submitter sits today.
#
# In the inbox a grant only surfaces submissions once the holder filters to that
# form type (InboxQuery#granted_submissions); on the Submissions page granted
# rows are always included (SubmissionsController#submission_scope_for).
module Forms
  class VisibilityGrant < ApplicationRecord
    self.table_name = 'form_visibility_grants'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormVisibilityGrant')

    GRANTEE_TYPES = %w[group employee].freeze

    # A grant on every form rather than one of them. Stored as a sentinel so the
    # column stays NOT NULL and the uniqueness scope keeps working.
    ALL_FORMS = '*'
    ALL_FORMS_LABEL = 'All forms'

    # Surfaces a grant can widen, and how the admin screen names them.
    APPLIES_TO_LABELS = {
      'both' => 'Inbox and Submissions',
      'submissions' => 'Submissions only',
      'inbox' => 'Inbox only'
    }.freeze
    APPLIES_TO = APPLIES_TO_LABELS.keys.freeze

    ORG_LEVELS = ::FormSearch::ORG_LEVELS

    belongs_to :group, foreign_key: :group_id, optional: true

    before_validation :normalize_org_scope

    validates :form_type, presence: true
    validates :grantee_type, inclusion: { in: GRANTEE_TYPES }
    validates :applies_to, inclusion: { in: APPLIES_TO }
    validates :group_id, presence: true, if: -> { grantee_type == 'group' }
    validates :employee_id, presence: true, if: -> { grantee_type == 'employee' }
    validates :form_type,
              uniqueness: { scope: %i[grantee_type group_id employee_id applies_to
                                      agency_id division_id department_id unit_id],
                            message: 'already has an identical grant' }

    scope :for_group, ->(group_id) { where(grantee_type: 'group', group_id: group_id) }
    scope :for_inbox, -> { where(applies_to: %w[both inbox]) }
    scope :for_submissions, -> { where(applies_to: %w[both submissions]) }

    # Every form type a grant can target: active dynamic templates plus the
    # legacy hand-written forms (kept in sync with
    # InboxHelper::HARDCODED_FORM_TYPES). Shared by the admin screen's Form
    # dropdown and by the inbox, which has to expand an "all forms" grant into
    # the types it actually covers.
    def self.form_type_catalog
      dynamic = Forms::Template.where(archived: false).order(:name).map do |template|
        { class_name: template.class_name, label: template.name }
      end
      legacy = InboxHelper::HARDCODED_FORM_TYPES.map do |class_name|
        { class_name: class_name, label: class_name.demodulize.titleize }
      end

      (dynamic + legacy).uniq { |form| form[:class_name] }.sort_by { |form| form[:label].to_s.downcase }
    end

    # Class names these grants cover, with any "all forms" grant expanded.
    def self.covered_form_types(grants)
      grants.flat_map { |grant| grant.all_forms? ? form_type_catalog.map { |form| form[:class_name] } : [grant.form_type] }
            .uniq
    end

    # Grants held by the given employee, directly or through one of their groups.
    def self.for_viewer(employee_id, group_ids)
      rel = where(grantee_type: 'employee', employee_id: employee_id)
      rel = rel.or(where(grantee_type: 'group', group_id: group_ids)) if group_ids.present?
      rel
    end

    # The rows of +model_class+ this set of grants opens up, or nil when none of
    # them covers this form type — so a caller can tell "no widening" from
    # "widened to nothing" and fall back to what the viewer could already see.
    def self.granted_scope(grants, model_class)
      scopes = grants.select { |grant| grant.covers?(model_class) }
                     .filter_map { |grant| grant.scope_for(model_class) }
      return nil if scopes.empty?

      scopes.reduce(:or)
    end

    # +own_scope+ widened by whatever these grants open up. Every consumer goes
    # through here so the Inbox, the Submissions page and PFA can't disagree
    # about what a grant means.
    def self.widen(own_scope, grants, model_class)
      granted = granted_scope(grants, model_class)
      granted ? own_scope.or(granted) : own_scope
    end

    # This grant's org window, expressed as the same FormSearch the Submissions
    # page builds from its Advanced Search panel. Reusing it keeps one
    # implementation of "narrow these submissions to an agency/division/
    # department/unit", including the HCA/HCAV agency spellings and the
    # per-agency display labels.
    def org_search
      ::FormSearch.new(filter_agency: agency_id, filter_division: division_id,
                       filter_department: department_id, filter_unit: unit_id)
    end

    def org_scoped?
      org_search.org_filters.any?
    end

    # The org window in words, e.g. ["Agency: General Services Agency",
    # "Department: Maintenance"]. Empty for a grant that spans the whole org.
    def org_summary
      org_search.summary
    end

    def all_forms?
      form_type == ALL_FORMS
    end

    def covers?(model_class)
      all_forms? || form_type == model_class.name
    end

    # How the admin screen names this grant's form. +labels+ maps class names to
    # the friendly names the catalog knows; anything else falls back to the class
    # name, so a grant on a form since archived still reads as something.
    def form_label(labels = {})
      return ALL_FORMS_LABEL if all_forms?

      labels[form_type] || form_type
    end

    def applies_to_label
      APPLIES_TO_LABELS.fetch(applies_to, applies_to.to_s.titleize)
    end

    # This grant's window over +model_class+, or nil when that model can't answer
    # the question the grant asks. A grant on one unit must contribute nothing to
    # a form that never recorded a unit — never every row.
    def scope_for(model_class)
      search = org_search
      levels = search.org_filters.keys
      return model_class.all if levels.empty?
      return nil unless levels.all? { |level| model_class.column_names.include?(level.to_s) }

      search.apply_org(model_class, model_class.all)
    end

    private

    # A blank org level means "all", and blank strings would otherwise make two
    # identical grants look different to the uniqueness check.
    def normalize_org_scope
      ORG_LEVELS.each do |level|
        attribute = "#{level}_id"
        self[attribute] = self[attribute].to_s.strip.presence
      end
    end
  end
end
