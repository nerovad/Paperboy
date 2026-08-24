# frozen_string_literal: true

class AddServiceAndBillingFieldsToNoticeOfChangeForms < ActiveRecord::Migration[8.0]
  def change
    change_table :notice_of_change_forms, bulk: true do |table|
      table.string :change_or_service_requested
      table.string :old_location_or_address
      table.string :new_location_or_address
      table.text :description_of_new_service
      %i[object activity function program phase task].each { |field| table.string field }
      table.string :monthly_cost
      table.string :annual_cost
    end
  end
end
