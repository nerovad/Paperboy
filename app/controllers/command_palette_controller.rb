# frozen_string_literal: true

# The contents of the command palette that ":" opens — the search box, the
# commands, everywhere in the system the viewer can go, and every blank form
# they may open.
#
# It is only ever fetched into the palette's turbo-frame, which the layout
# renders on every page and no one loads until the first ":", so this renders
# without a layout. Building the form list costs a query, which is exactly why
# it is not built until somebody asks.
class CommandPaletteController < ApplicationController
  layout false

  def show
    return head(:forbidden) unless current_user

    @catalog = FormCatalog.new(admin: helpers.system_admin?,
                               permitted_keys: current_user_form_permission_keys)
    @navigation = NavigationCatalog.new(helpers)
  end
end
