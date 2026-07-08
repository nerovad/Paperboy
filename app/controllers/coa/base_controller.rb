module Coa
  class BaseController < ApplicationController
    before_action :require_system_admin
  end
end
