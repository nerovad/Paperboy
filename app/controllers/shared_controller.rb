class SharedController < ApplicationController
  def form_success
    render layout: "application"
  end

  def ticket_success
    render layout: "application"
  end
end
