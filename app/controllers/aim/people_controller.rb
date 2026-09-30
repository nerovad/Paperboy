# frozen_string_literal: true

module Aim
  # Search the people who work AIM for one to own a queue, the way the Chart
  # of Accounts employee lookup searches (Employee.search_ranked: name,
  # "First Last" or id, a full id first), labelled "Last, First (id)" with the
  # unit beside it. AIM's own endpoint, so AIM's access rules apply rather
  # than COA's. Open to anyone signed in: whoever holds an invoice may hand it
  # to someone's queue.
  class PeopleController < BaseController
    SEARCH_LIMIT = 20

    def index
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      # Only people who work AIM have a queue to send an invoice to.
      people = Employee.where(id: Aim::Users.all.pluck(:id))
      render json: people.search_ranked(query).limit(SEARCH_LIMIT).search_options
    end
  end
end
