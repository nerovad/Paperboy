class AddAuthorizationServiceTypeToRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    # Service type (P/E/V/C/K) for routing_type == 'authorization' steps, which
    # route to whoever holds that authorization for the submission's budget unit.
    add_column :form_template_routing_steps, :authorization_service_type, :string
  end
end
