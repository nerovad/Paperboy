# frozen_string_literal: true

class FormsController < ApplicationController
  # The landing page: where signed-out visitors find the Login button.
  skip_before_action :require_sign_in, only: :home

  def home; end
end
