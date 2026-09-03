# frozen_string_literal: true

module Coa
  class BaseController < ApplicationController
    before_action :require_app_access

    helper_method :coa_sidebar_resources, :coa_sidebar_collection_path, :coa_feature_key,
                  :coa_table_label, :coa_budget_unit?

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it Chart of Accounts would stay reachable
    # by typing the URL. Access is granted per group or org level under
    # ACL > Applications; each table below is a separate grant under ACL >
    # Application Features, so getting in never implies seeing everything.
    # System admins bypass both.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('coa')

      redirect_to root_path, alert: 'You do not have access to Chart of Accounts.'
    end

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
