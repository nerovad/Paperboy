# app/models/form_reference.rb
#
# Human-facing reference numbers for form submissions, e.g. "PLS-845".
#
# A reference is simply "<prefix>-<id>" where the prefix identifies the form
# type and the id is the record's primary key. References are therefore unique
# *within* a form type and, combined with the prefix, unique across the system —
# the prefix is what tells the inbox search which table a number belongs to.
#
# The stored FormTemplate#reference_prefix is the runtime source of truth (admin-
# editable per form). PREFIX_SEEDS supplies nicer starting values for a few forms
# on backfill/create, and derive_prefix is the last-resort fallback.
module FormReference
  # Preferred starting prefixes for specific forms, used to seed the template
  # column on backfill/create (nicer than the auto-derived initials). The stored
  # FormTemplate#reference_prefix is the source of truth at runtime — these only
  # supply the initial value and act as a fallback when no prefix is stored.
  PREFIX_SEEDS = {
    'ParkingLotSubmission' => 'PLS',
    'ProbationTransferRequest' => 'PTR',
    'CriticalInformationReporting' => 'CIR'
  }.freeze

  # Common class-name suffixes stripped before deriving an initials prefix.
  SUFFIX_RE = /(Form|Submission|Request|Reporting)\z/

  module_function

  # class_name => prefix for every known form. Template-backed forms supply
  # their (admin-editable) reference_prefix; the custom forms fall back to the
  # constant map. One query — cache the result (e.g. in a controller ivar) when
  # rendering many rows so each row doesn't re-hit the database.
  def prefix_map
    PREFIX_SEEDS.merge(
      FormTemplate.where.not(reference_prefix: [nil, ''])
                  .pluck(:class_name, :reference_prefix)
                  .to_h
    )
  end

  # Prefix for a single record or class. The stored template prefix wins; the
  # seed map and derived initials are only fallbacks. Pass a prefix_map (built
  # the same way) to avoid a query when resolving many records.
  def prefix_for(record_or_class, map = nil)
    class_name = record_or_class.is_a?(Class) ? record_or_class.name : record_or_class.class.name
    return map[class_name] || derive_prefix(class_name) if map

    FormTemplate.where(class_name: class_name).where.not(reference_prefix: [nil, '']).pick(:reference_prefix) ||
      PREFIX_SEEDS[class_name] ||
      derive_prefix(class_name)
  end

  # Human-facing reference, e.g. "PLS-845". Returns nil for an unsaved record.
  def reference_for(record, map = nil)
    return nil unless record.respond_to?(:id) && record.id

    "#{prefix_for(record, map)}-#{record.id}"
  end

  # Fallback prefix from the class name's capital initials, minus the common
  # form suffixes: "LeaveOfAbsenceForm" => "LOA". Used to seed new templates and
  # as a last resort when no prefix is stored. Not guaranteed unique on its own —
  # callers that need uniqueness (template creation/backfill) must dedupe.
  def derive_prefix(class_name)
    base = class_name.to_s.demodulize.sub(SUFFIX_RE, '')
    letters = base.scan(/[A-Z]/).join
    letters = base[0, 3].to_s.upcase if letters.length < 2
    letters.presence || 'FORM'
  end

  # Normalize a user-typed reference for matching: trim and upcase.
  def normalize(query)
    query.to_s.strip.upcase
  end

  # Does `reference` (e.g. "PLS-845") match a user-typed query? Accepts the full
  # reference ("PLS-845" / "pls-845"), a prefix to narrow by form ("PLS"), or the
  # id portion whole or partial ("845" / "84").
  def matches?(reference, query)
    return false if reference.blank? || query.blank?

    ref = reference.upcase
    q   = normalize(query)
    id_part = ref.split('-').last.to_s
    ref.start_with?(q) || id_part.start_with?(q)
  end
end
