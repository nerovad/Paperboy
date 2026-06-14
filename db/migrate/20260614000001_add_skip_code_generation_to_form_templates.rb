class AddSkipCodeGenerationToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    # When true, the form builder manages this template's routing steps,
    # statuses, email steps and copy recipients (records the model + inbox act
    # on), but never regenerates its controller, views or model. For forms whose
    # controller/views are hand-written (e.g. ParkingLotSubmission).
    add_column :form_templates, :skip_code_generation, :boolean, null: false, default: false
  end
end
