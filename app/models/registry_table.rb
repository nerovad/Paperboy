# frozen_string_literal: true

# Catalog of the "Records" tables — the models that `include Registry`. The
# member list is explicit so lookups are reliable regardless of autoload /
# eager-load state: add a model name here when you add a Records table.
#
# Instances wrap a registry model and expose its declared metadata to the
# controllers, the column customizer (TableColumns) and ingestion.
class RegistryTable
  MODEL_NAMES = %w[PcardInventory FleetVehicle].freeze

  class << self
    def models
      MODEL_NAMES.map(&:constantize)
    end

    # All Records tables: the code-declared model-backed tables plus the
    # form-backed tables an admin has flagged (see FormBackedTable).
    def all
      models.map { |model| new(model) } + FormBackedTable.all
    end

    # Look up a table by its slug (the "records:<slug>" page key). Form-backed
    # slugs are "form-<id>"; everything else is a model-backed table.
    def find(slug)
      slug = slug.to_s
      return FormBackedTable.find(slug) if slug.start_with?(FormBackedTable::SLUG_PREFIX)

      model = models.find { |m| m.registry_slug == slug }
      model && new(model)
    end

    # Find the table whose declared source form matches a submission's class.
    def for_source(form_class)
      model = models.find { |m| m.registry_source_config&.dig(:form_class) == form_class }
      model && new(model)
    end
  end

  attr_reader :model

  def initialize(model)
    @model = model
  end

  def slug = model.registry_slug
  def label = model.registry_label
  def permission = model.registry_permission
  def dropdown_key = model.registry_dropdown_key
  def route = model.registry_route
  def columns = model.registry_columns
  def page_key = "records:#{slug}"

  def count = model.count

  # Row set for a grid, with any declared associations eager-loaded.
  def scope
    model.registry_eager_load ? model.includes(model.registry_eager_load) : model.all
  end

  def ingest(form)
    model.ingest_from(form)
  end
end
