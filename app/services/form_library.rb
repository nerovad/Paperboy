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
#   library.collections   # the Forms::Collections this viewer has forms in
#   library.collection    # the group being browsed, or nil
#
# Everything starts from a FormCatalog, so the ACL has already been applied and
# no search here can surface a form the viewer may not open. A collection does
# not change that: it names forms, and each viewer sees the ones in it that
# their own ACL allows — which may be some, all or none. Every criterion is
# read from the request, so a search is its URL and can be bookmarked.
class FormLibrary
  # One form in the library. `key` is what the form ACL and a collection both
  # know it by. A legacy form with no template row has a name and a path and
  # nothing else to search on.
  Entry = Struct.new(:key, :name, :path, :template) do
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

  attr_reader :catalog, :params

  # `manager` is someone who may create and edit collections. They are shown
  # every collection, including one none of their own forms are in — a new
  # collection is empty, and its maker has to be able to find it again.
  #
  # `hidden_keys` are the forms the viewer has taken off their own sidebar.
  # The library still lists them — it is where they are put back.
  def initialize(catalog, params = {}, collections: nil, manager: false, hidden_keys: [])
    @catalog = catalog
    @hidden_keys = hidden_keys
    raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    @params = raw.with_indifferent_access
    @all_collections = collections
    @manager = manager
  end

  def manager? = @manager

  def hidden_from_sidebar?(entry) = @hidden_keys.include?(entry.key)

  # Every form the viewer may open, alphabetical.
  def entries
    @entries ||= catalog.forms.map do |name, path|
      Entry.new(catalog.key_for(name), name, path, catalog.template_for(name))
    end
  end

  def results
    @results ||= entries.select { |entry| matches?(entry) }
  end

  # [[collection, form count], …]. The count is of the forms this viewer may
  # open, so it always agrees with what the collection's page will list. A
  # collection holding none of them is left out, except for a manager.
  def collections
    @collections ||= all_collections.filter_map do |collection|
      count = entries.count { |entry| member?(collection, entry) }
      [collection, count] if count.positive? || manager?
    end
  end

  # The groups to offer beside the results. The search box finds collections
  # as well as forms, so typing "safety" brings up the Safety collection above
  # the forms that mention it. The facets describe forms and leave these alone.
  def matching_collections
    collections.select { |group, _| terms.all? { |term| group.haystack.include?(term) } }
  end

  # The collection being browsed. An unknown id, or a collection this viewer
  # has no forms in, is nil: the caller answers that as a missing page, so a
  # collection's existence is not given away to someone it holds nothing for.
  def collection
    return @collection if defined?(@collection)

    @collection = collections.map(&:first).find { |candidate| candidate.id.to_s == params[:collection].to_s }
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
    collection.nil? || member?(collection, entry)
  end

  def member?(collection, entry)
    collection.form_keys.include?(entry.key)
  end

  def all_collections
    @all_collections ||= Forms::Collection.alphabetical.includes(:collection_forms).to_a
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
