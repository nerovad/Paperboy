# frozen_string_literal: true

# app/controllers/environment_access_controller.rb
#
# Where ApplicationController#require_environment_access sends a signed-in
# visitor who holds no grant for Development or Stage: one page saying what
# this server is for, with a way on to Production and to the support channel.
class EnvironmentAccessController < ApplicationController
  # This is the page the gate redirects to.
  skip_before_action :require_environment_access

  def show
    return redirect_to(root_path) if environment_access_granted?

    @environment_label = EnvironmentAccess.label_for(environment_access_key)
  end
end
