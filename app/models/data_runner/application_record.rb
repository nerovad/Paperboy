# frozen_string_literal: true

module DataRunner
  class ApplicationRecord < ActiveRecord::Base
    primary_abstract_class
  end
end
