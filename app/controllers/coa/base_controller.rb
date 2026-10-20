# frozen_string_literal: true

module Coa
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'coa', label: 'Chart of Accounts'

    helper_method :coa_sidebar_resources, :coa_sidebar_collection_path, :coa_feature_key,
                  :coa_table_label, :coa_budget_unit?

    private

    # The tables this user may open, in sidebar order. Filtered rather than
    # gated wholesale so the sidebar and the row-count overview on the COA
    # index both show exactly what the grants allow.
    def coa_sidebar_resources
      Coa::Tables.models.select { |model_class| helpers.can_use_app_feature?('coa', coa_feature_key(model_class)) }
    end

    # A table's ACL feature key is its route collection name, so the sidebar
    # button and the controller behind it are gated by the same string.
    def coa_feature_key(model_class)
      Coa::Tables.collection_for(model_class)
    end

    def coa_table_label(model_class)
      Coa::Tables.label_for(model_class)
    end

    def coa_budget_unit?(model_class)
      Coa::Tables.budget_unit?(model_class)
    end

    def coa_sidebar_collection_path(model_class)
      public_send("coa_#{coa_feature_key(model_class)}_path")
    end
  end
end
