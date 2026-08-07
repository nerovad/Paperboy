# frozen_string_literal: true

# Mixed into the DAM records the Dashboard can star and remember: assets and
# collections.
#
# Favourites and recent views are polymorphic, so no foreign key cleans them up
# when their subject goes away. Left alone, deleting a collection leaves rows
# that count toward the Dashboard's eight slots and render as nothing.
module DamDashboardSubject
  extend ActiveSupport::Concern

  included do
    after_destroy :clear_dam_dashboard_rows
  end

  private

  def clear_dam_dashboard_rows
    Dam::Favorite.where(favoritable_type: self.class.name, favoritable_id: id).delete_all
    Dam::RecentView.where(viewable_type: self.class.name, viewable_id: id).delete_all
  end
end
