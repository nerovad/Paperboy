# frozen_string_literal: true

module Dam
  # Turns the sidebar search box and the Advanced Search modal into one query.
  #
  # Both entry points GET the same action with the same parameter names — the
  # sidebar simply sends `q` and nothing else — so there is one place that
  # decides what a DAM search means, a search is always reproducible from its
  # URL, and a saved search is just these params.
  #
  #   Dam::AssetSearch.new(params).results
  #
  # Custom metadata criteria arrive as a nested hash keyed by row index, since
  # the modal lets you add as many as you like:
  #
  #   meta: { "0" => { field: "campaign", operator: "contains", value: "summer" } }
  #
  # Their type-dependent handling lives in Dam::MetadataFilter.
  class AssetSearch
    # Free-text `q` is matched against these asset columns, plus every custom
    # metadata value (see #apply_text).
    TEXT_COLUMNS = %w[title description filename].freeze

    SORTS = {
      'newest' => { created_at: :desc },
      'oldest' => { created_at: :asc },
      'title' => { title: :asc },
      'largest' => { byte_size: :desc }
    }.freeze

    attr_reader :params

    def initialize(params = {})
      raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      @params = raw.with_indifferent_access
    end

    def results
      scope = Dam::Asset.visible.includes(:storage_location).with_attached_file
      scope = apply_text(scope)
      scope = apply_facets(scope)
      scope = apply_dates(scope)
      scope = apply_metadata(scope)
      scope.order(SORTS.fetch(sort, SORTS['newest']))
    end

    def query = params[:q].to_s.strip

    def sort = SORTS.key?(params[:sort]) ? params[:sort] : 'newest'

    def media_types = Array(params[:media_type]).compact_blank

    def formats = Array(params[:format]).compact_blank

    def storage_location_ids = Array(params[:storage_location_id]).compact_blank

    def uploaded_by = params[:uploaded_by].to_s.strip

    def created_from = params[:created_from].to_s

    def created_to = params[:created_to].to_s

    def metadata_filters
      @metadata_filters ||= Dam::MetadataFilter.from_params(params[:meta], known_fields)
    end

    # True when anything beyond the plain text box was set. The sidebar uses
    # this to mark the Advanced Search button as carrying filters.
    def advanced?
      media_types.any? || formats.any? || storage_location_ids.any? ||
        uploaded_by.present? || created_from.present? || created_to.present? ||
        metadata_filters.any?
    end

    def any? = query.present? || advanced?

    # One line per active filter, for the chips above the results.
    def summary
      chips = []
      chips << "Search: #{query}" if query.present?
      chips << "Media: #{media_types.map(&:titleize).join(', ')}" if media_types.any?
      chips << "Format: #{formats.join(', ')}" if formats.any?
      chips << "Created by: #{uploader_label}" if uploaded_by.present?
      chips << "Storage: #{storage_labels.join(', ')}" if storage_location_ids.any?
      chips << "From #{created_from}" if created_from.present?
      chips << "To #{created_to}" if created_to.present?
      chips + metadata_filters.map(&:chip)
    end

    private

    def apply_text(scope)
      return scope if query.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      clause = TEXT_COLUMNS.map { |column| "dam_assets.#{column} LIKE :pattern" }.join(' OR ')
      # Metadata is reached through a subquery rather than a join, so an asset
      # with three matching values still comes back once. Composed with #or
      # rather than interpolating the subquery's SQL, which reads to a scanner
      # (correctly) as string-built SQL.
      metadata_ids = Dam::MetadataValue.where('value LIKE ?', pattern).select(:asset_id)
      scope.where(clause, pattern: pattern).or(scope.where(id: metadata_ids))
    end

    def apply_facets(scope)
      scope = scope.where(media_type: media_types) if media_types.any?
      scope = scope.where(format: formats) if formats.any?
      scope = scope.where(storage_location_id: storage_location_ids) if storage_location_ids.any?
      scope = scope.where(uploaded_by_id: uploaded_by) if uploaded_by.present?
      scope
    end

    def apply_dates(scope)
      from = parse_time(created_from)
      to = parse_time(created_to)
      scope = scope.where(created_at: from..) if from
      # Inclusive of the whole end day — someone picking today expects today's
      # uploads, not everything up to midnight this morning.
      scope = scope.where(created_at: ..to.end_of_day) if to
      scope
    end

    # Each criterion narrows by asset id, so several compose as AND across
    # different fields rather than fighting over one join.
    def apply_metadata(scope)
      metadata_filters.reduce(scope) do |current, filter|
        ids = filter.asset_ids
        ids ? current.where(id: ids) : current
      end
    end

    def known_fields
      @known_fields ||= Dam::MetadataField.active.index_by(&:key)
    end

    def uploader_label
      Dam::Asset.where(uploaded_by_id: uploaded_by).pick(:uploaded_by_name).presence || uploaded_by
    end

    def storage_labels
      Dam::StorageLocation.where(id: storage_location_ids).order(:label).pluck(:label)
    end

    def parse_time(raw)
      return nil if raw.blank?

      Time.zone.parse(raw.to_s)
    rescue ArgumentError
      nil
    end
  end
end
