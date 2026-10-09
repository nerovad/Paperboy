# frozen_string_literal: true

# The Form Library — every blank form a person may fill out, on a page of its
# own, narrowed by what the request asks for.
#
# The sidebar lists the same forms by name. This is where its Advanced Search
# button leads: the same list with each form's number, description, issuing org
# and tags beside it, and room to narrow on them.
#
#   library = FormLibrary.new(catalog, params)
#   library.results       # the entries that survive the search
#   library.collections   # the named groups this viewer has forms in
#   library.collection    # the group being browsed, or nil
#
# Everything starts from a FormCatalog, so the ACL has already been applied and
# no search here can surface a form the viewer may not open. Every criterion is
# read from the request, so a search is its URL and can be bookmarked.
class FormLibrary
  COLLECTIONS_FILE = Rails.root.join('config/form_collections.yml')

  # One form in the library. A legacy form with no template row has a name and
  # a path and nothing else to search on.
  Entry = Struct.new(:name, :path, :template) do
    def number = template&.form_number.to_s

    def description = template&.description.to_s

    def form_type = template&.form_type.to_s

    def tags = template&.tags_array || []

    def org_code(level) = template ? template[:"#{level}_id"].to_s.strip : ''

    def field_labels = template ? template.form_fields.map(&:label) : []

    # Everything the search box matches against, lowercased once.
    def haystack
      @haystack ||= [name, number, description, tags, field_labels].flatten.join(' ').downcase
    end
  end

  # A named group of forms. See config/form_collections.yml for the rules.
  Collection = Struct.new(:key, :name, :description, :tags, :agencies, :forms) do
    def include?(entry)
      forms.include?(entry.name) ||
        agencies.include?(entry.org_code(:agency)) ||
        entry.tags.any? { |tag| tags.include?(tag.downcase) }
    end

    # What the search box matches a collection on: what it is called, what it
    # says it holds and the tags that fill it.
    def haystack
      @haystack ||= [name, description, tags].flatten.join(' ').downcase
    end
  end

  # Built per call rather than memoized on the class, so an edit to the file
  # shows on the next request in development.
  def self.defined_collections
    YAML.safe_load_file(COLLECTIONS_FILE).map do |key, config|
      Collection.new(key, config['name'], config['description'].to_s,
                     Array(config['tags']).map(&:downcase),
                     Array(config['agencies']), Array(config['forms']))
    end
  end

  attr_reader :catalog, :params

  def initialize(catalog, params = {}, collections: self.class.defined_collections)
    @catalog = catalog
    raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    @params = raw.with_indifferent_access
    @defined_collections = collections
  end

  # Every form the viewer may open, alphabetical.
  def entries
    @entries ||= catalog.forms.map { |name, path| Entry.new(name, path, catalog.template_for(name)) }
  end

  def results
    @results ||= entries.select { |entry| matches?(entry) }
  end

  # [[collection, form count], …] — only the groups this viewer has forms in.
  def collections
    @collections ||= @defined_collections.filter_map do |collection|
      count = entries.count { |entry| collection.include?(entry) }
      [collection, count] if count.positive?
    end
  end

  # The groups to offer beside the results. The search box finds collections
  # as well as forms, so typing "safety" brings up the Safety collection above
  # the forms that mention it. The facets describe forms and leave these alone.
  def matching_collections
    collections.select { |group, _| terms.all? { |term| group.haystack.include?(term) } }
  end

  # The group being browsed. An unknown key, or one the viewer has no forms
  # in, is nil: the caller answers that as a missing page.
  def collection
    return @collection if defined?(@collection)

    @collection = collections.map(&:first).find { |candidate| candidate.key == params[:collection].to_s }
  end

  def finder = catalog.finder

  # --- What the request asked for --------------------------------------------

  def query = params[:q].to_s.strip

  def org
    @org ||= FormSearch.new(params)
  end

  def form_types = list(:type)

  def tags = list(:tag)

  # Tags in use across the viewer's forms, one spelling each: "Security" and
  # "security" are the same tag typed twice.
  def tag_options
    finder.tags.uniq(&:downcase)
  end

  # True when the search box or a facet is narrowing the list. Browsing a
  # collection is not, on its own, a filter.
  def filtered?
    query.present? || org.org_filters.any? || form_types.any? || tags.any?
  end

  def org_path(entry)
    entry.template ? finder.org_path(entry.template) : ''
  end

  private

  # Every criterion set has to hold; within the type and tag boxes any one
  # ticked value will do — the rule the sidebar panel used.
  def matches?(entry)
    in_collection?(entry) && matches_query?(entry) && matches_org?(entry) &&
      matches_any?([entry.form_type], form_types) &&
      matches_any?(entry.tags, tags)
  end

  def in_collection?(entry)
    collection.nil? || collection.include?(entry)
  end

  # Every word typed has to appear somewhere on the form.
  def matches_query?(entry)
    terms.all? { |term| entry.haystack.include?(term) }
  end

  def terms
    @terms ||= query.downcase.split
  end

  # A form not tied to an org cannot answer "issued by HCA", so it drops out
  # once an org is chosen rather than riding along with every search.
  def matches_org?(entry)
    org.org_filters.all? { |level, code| entry.org_code(level) == code }
  end

  def matches_any?(values, wanted)
    wanted.empty? || values.any? { |value| wanted.include?(value.downcase) }
  end

  def list(key)
    Array(params[key]).map { |value| value.to_s.strip.downcase }.compact_blank
  end
end
