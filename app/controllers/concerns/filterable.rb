# app/controllers/concerns/filterable.rb
module Filterable
  extend ActiveSupport::Concern

  private

  # Collect unique values for filter dropdowns from a collection
  # field_mappings: Hash of { filter_name => lambda/proc to extract value }
  # Example: { form_types: ->(item) { item.class.name.demodulize.titleize } }
  def collect_filter_options(collection, field_mappings)
    options = {}

    field_mappings.each do |key, extractor|
      values = collection.map { |item| extractor.call(item) }.compact.uniq
      options[key] = values.sort_by { |v| v.to_s.downcase }
    end

    options
  end

  # Apply filters to a collection
  # filter_configs: Array of { param:, extractor: } hashes
  # date_filters: Array of { param:, extractor:, comparison: } hashes
  def apply_filters(collection, filter_configs: [], date_filters: [])
    filtered = collection

    # Apply standard filters
    filter_configs.each do |config|
      param_value = params[config[:param]]
      next unless param_value.present?

      filtered = filtered.select do |item|
        extractor = config[:extractor]
        item_value = extractor.call(item)
        item_value.to_s == param_value.to_s
      end
    end

    # Apply date filters
    date_filters.each do |config|
      param_value = params[config[:param]]
      next unless param_value.present?

      date = Date.parse(param_value)
      date = config[:comparison] == :from ? date.beginning_of_day : date.end_of_day

      filtered = filtered.select do |item|
        item_date = config[:extractor].call(item)
        if config[:comparison] == :from
          item_date >= date
        else
          item_date <= date
        end
      end
    end

    filtered
  end

  # Sort a collection by a given field
  # sort_configs: Hash of { sort_key => lambda to extract sort value }
  def sort_collection(collection, sort_by, sort_direction, sort_configs, default_sort: 'created_at')
    sort_key = sort_configs.key?(sort_by) ? sort_by : default_sort
    extractor = sort_configs[sort_key]

    sorted = collection.sort_by { |item| extractor.call(item).to_s.downcase }
    sort_direction == 'desc' ? sorted.reverse : sorted
  end

  # Helper to check if any filters are active
  def filters_active?(*filter_params)
    filter_params.any? { |param| params[param].present? }
  end
end
