class CreateFormSubmissionCopies < ActiveRecord::Migration[8.0]
  def change
    create_table :form_submission_copies do |t|
      t.string :submission_type, null: false
      t.bigint :submission_id, null: false
      t.integer :recipient_employee_id, null: false
      t.string :delivered_via, null: false
      t.datetime :dismissed_at
      t.timestamps
    end

    add_index :form_submission_copies, %i[submission_type submission_id], name: 'index_form_submission_copies_on_submission'
    add_index :form_submission_copies, :recipient_employee_id
    add_index :form_submission_copies,
              %i[submission_type submission_id recipient_employee_id],
              unique: true,
              name: 'index_form_submission_copies_unique_per_recipient'
  end
end
