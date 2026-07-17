# frozen_string_literal: true

# Landing page for the Records pillar: the grid tables (see Registry) the
# current user may open. Access is per-table; a user who can open none of them
# is bounced to root.
class RecordsController < ApplicationController
  before_action :load_records_tables

  def index; end

  private

  def load_records_tables
    @tables = helpers.records_portal_tables
    redirect_to root_path, alert: 'Access denied.' if @tables.empty?
  end
end
