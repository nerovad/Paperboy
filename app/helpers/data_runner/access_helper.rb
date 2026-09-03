# frozen_string_literal: true

module DataRunner
  # Which DSLs a person may open.
  #
  # Data Runner's sidebar is its DSL catalog, so gating the sidebar means
  # gating the catalog: every DSL is an ACL > Application Features grant under
  # Data Runner (see AppFeature.data_runner_dsl_features). Getting into the app
  # no longer implies seeing everything in it, which is how COA's tables and
  # Billing's buttons have always worked.
  #
  # A helper rather than a controller method because four surfaces ask: the
  # Data Runner sidebar, its index page, the controllers that open a DSL, and
  # the command palette — which asks from apps where no Data Runner controller
  # is running.
  module AccessHelper
    # Reorganizing the catalog means seeing all of it. Somebody who can drag a
    # DSL from one group to another is administering the catalog, and a
    # half-visible drag-and-drop surface would only lie about what is in it.
    def can_use_dsl?(slug)
      can_use_app_feature?('data_runner', 'manage_groups') ||
        can_use_app_feature?('data_runner', AppFeature.dsl_key(slug))
    end

    def permitted_dsls
      DslCatalog.entries.select { |entry| can_use_dsl?(entry.slug) }
    end

    # The sidebar's two lists, filtered. Shapes match DslCatalog.grouped and
    # DslCatalog.ungrouped so the sidebar reads the same as it did.
    def permitted_grouped_dsls
      permitted_dsls.select(&:group).group_by(&:group).sort.to_h
    end

    def permitted_ungrouped_dsls
      permitted_dsls.reject(&:group)
    end
  end
end
