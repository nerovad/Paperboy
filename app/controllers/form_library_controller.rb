# frozen_string_literal: true

# The Form Library: the full page behind the sidebar's Advanced Search button,
# and the page each collection of forms gets to itself.
#
# Both are one action. A collection is the same list already narrowed to a
# named group, and the search box and facets keep working inside it.
class FormLibraryController < ApplicationController
  def index
    catalog = FormCatalog.new(admin: helpers.system_admin?,
                              permitted_keys: current_user_form_permission_keys)
    @library = FormLibrary.new(catalog, params,
                               manager: helpers.can_use_app_feature?('paperboy', 'form_collections'),
                               hidden_keys: UserSetting.hidden_form_keys_for(current_user.employee_id))

    head :not_found if params[:collection].present? && @library.collection.nil?
  end
end
