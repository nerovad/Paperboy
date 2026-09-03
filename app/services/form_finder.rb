# frozen_string_literal: true

# Advanced Search over the forms you can *fill out* — the facets in the
# sidebar's panel, and the rule for whether a form survives them.
#
# Not to be confused with FormSearch, which searches forms already submitted
# and lives on the Submissions list. This one never reads a submission row: it
# narrows the sidebar's list of blank forms by the metadata an admin set on the
# template in the form builder (see Forms::Template's FORM_TYPES and org
# columns).
#
#   finder = FormFinder.new(visible_templates)
#   finder.org_tree        # every org code in use, nested for the cascade
#   finder.form_types      # only the kinds of form actually present
#   finder.tags            # every tag in use
#
# Facets are built from the templates handed in — the ones that survived the
# ACL for this viewer — rather than from every template in the database, so the
# panel can never offer a choice that returns nothing. Narrowing itself happens
# in the browser: the sidebar has already rendered every link the viewer may
# use, so there is nothing to fetch and no round trip to wait on.
class FormFinder
  # Each level of the cascade, paired with the model that names its codes and
  # how a chosen row is written out. Unit keeps its code in the label because a
  # unit's name means little without it — the same wording FormSearch uses.
  LEVELS = {
    agency: { model: Coa::Agency, key: :agency_id },
    division: { model: Coa::Division, key: :division_id },
    department: { model: Coa::Department, key: :department_id },
    unit: { model: Coa::Unit, key: :unit_id, label: ->(code, name) { "#{code} - #{name}" } }
  }.freeze

  attr_reader :templates

  def initialize(templates)
    @templates = Array(templates)
  end

  # The org codes in use, nested by parent so choosing an agency can fill the
  # divisions without asking the server:
  #
  #   { agencies:    [["Health Care Agency", "HCA"], …],
  #     divisions:   { "HCA" => […] },
  #     departments: { "300" => […] },
  #     units:       { "3014" => […] } }
  def org_tree
    {
      agencies: level_options(:agency),
      divisions: child_options(:agency, :division),
      departments: child_options(:division, :department),
      units: child_options(:department, :unit)
    }
  end

  # Only the kinds of form actually present, in the vocabulary's own order
  # rather than alphabetically — the list reads as a sequence, not a jumble.
  def form_types
    present = templates.filter_map { |template| template.form_type.presence }.uniq
    Forms::Template::FORM_TYPES & present
  end

  def tags
    templates.flat_map(&:tags_array).uniq.sort_by(&:downcase)
  end

  # Whether the panel has anything to offer. False means no admin has filled in
  # any metadata yet, and the panel says so rather than showing empty boxes.
  def any_facets?
    templates.any?(&:searchable_metadata?)
  end

  # One line naming the part of the county a form belongs to, outermost level
  # first, in the names the org tables use. Blank when the form is not tied to
  # an org. Every template handed to this finder is named from the same two
  # queries per level, so a page listing all of them still costs a handful.
  def org_path(template)
    template.org_codes.map { |level, code| names_for(level)[code] || code }.join(' › ')
  end

  private

  # Code → label for one level across every template handed in, resolved once.
  def names_for(level)
    @names_for ||= {}
    @names_for[level] ||= labelled(level, codes_at(level)).to_h { |label, code| [code, label] }
  end

  # Distinct codes at one level, labelled from the org tables. A code the org
  # tables no longer carry still gets offered under its own code — the form
  # really is tagged that way, and hiding it would make the form unreachable
  # from the panel.
  def level_options(level)
    labelled(level, codes_at(level))
  end

  # Codes at one level grouped by the code above them, so the browser can look
  # up a level's options by its parent's value.
  def child_options(parent, child)
    pairs = templates.filter_map do |template|
      up = code(template, parent)
      down = code(template, child)
      [up, down] if up.present? && down.present?
    end.uniq

    names = labelled(child, pairs.map(&:last)).to_h { |label, value| [value, label] }
    pairs.group_by(&:first).transform_values do |group|
      group.map { |(_, down)| [names[down] || down, down] }.uniq.sort_by { |label, _| label.to_s.downcase }
    end
  end

  def codes_at(level)
    templates.filter_map { |template| code(template, level).presence }.uniq
  end

  def code(template, level)
    template[:"#{level}_id"].to_s.strip
  end

  # [label, code] pairs for a set of codes, sorted by label.
  def labelled(level, wanted)
    return [] if wanted.empty?

    config = LEVELS.fetch(level)
    names = config[:model].where(config[:key] => wanted).pluck(config[:key], :long_name).to_h
    format = config[:label] || ->(_code, name) { name }

    wanted.map { |value| [names[value] ? format.call(value, names[value]) : value, value] }
          .sort_by { |label, _| label.to_s.downcase }
  end
end
