# frozen_string_literal: true

module Aim
  # AIM administration: who works AIM, which budget units they cover, and
  # the shared queue of each BU. Placeholder until it is built.
  class AdminController < BaseController
    before_action :require_aim_admin

    def index; end
  end
end
