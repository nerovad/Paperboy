# frozen_string_literal: true

module Aim
  # Search for a person to own a queue, the way the Chart of Accounts
  # employee lookup searches: by first name, last name or employee id, and
  # labelled "Last, First (id)" with the unit beside it. AIM's own endpoint,
  # so AIM's access rules apply rather than COA's.
  class PeopleController < BaseController
    SEARCH_LIMIT = 20

    def index
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      matches = matching(query).order(:last_name, :first_name).limit(SEARCH_LIMIT)
                               .pluck(:id, :first_name, :last_name, :unit)
      render json: matches.map { |id, first, last, unit|
        { value: id, label: "#{last}, #{first} (#{id})", unit: unit }
      }
    end

    private

    def matching(query)
      return Employee.where(id: query) if query.match?(/\A\d+\z/)

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      Employee.where('first_name LIKE :query OR last_name LIKE :query', query: pattern)
    end
  end
end
