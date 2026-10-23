# frozen_string_literal: true

module HumanResources
  class GridsController < BaseController
    include Pagy::Method

    def show
      @definition = GridCatalog.find!(params[:id])
      @query = params[:q].is_a?(String) ? params[:q] : ''
      count = GridReader.count(@definition, query: @query)
      @pagy, = pagy(:offset, [], count: count, limit: Pfa::Grid::Table::PAGE_ROWS)
      loaded = GridReader.rows(@definition, offset: @pagy.offset, limit: @pagy.limit, query: @query)
      @grid = Pfa::Grid::Table.new(columns: @definition.columns.map { |name| { label: name } }, rows: loaded)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("Human Resources grid #{@definition.slug} failed: #{e.message}")
      @error = "#{@definition.table} could not be read."
    end
  end
end
