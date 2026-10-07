# frozen_string_literal: true

# Email rules and copy recipients can name an Authorization Console, the way a
# routing step does. The column holds the same routing key as
# form_template_routing_steps.authorization_service_type.
class AddAuthorizationServiceTypeToFormRecipients < ActiveRecord::Migration[8.1]
  def change
    add_column :form_template_email_steps, :authorization_service_type, :string
    add_column :form_template_copy_recipients, :authorization_service_type, :string
  end
end
