# frozen_string_literal: true

module Coa
  class ListController < BaseController
    helper_method :coa_resources, :collection_path

    # Slideshow landing (COA root). Functional navigation lives in the
    # sidebar; the row-count overview is still available at #index.
    def home; end

    def index; end

    private

    def coa_resources
      coa_sidebar_resources
    end

    def collection_path(model_class)
      coa_sidebar_collection_path(model_class)
    end
  end
end
