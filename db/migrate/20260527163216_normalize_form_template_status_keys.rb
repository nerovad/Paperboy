class NormalizeFormTemplateStatusKeys < ActiveRecord::Migration[8.0]
  # Phase 1 of the status-key consolidation: normalize the central
  # form_template_statuses *definition* rows into the canonical vocabulary.
  # Idempotent. Submission data (the integer status columns on each form
  # table) is migrated separately in a later phase.
  def up
    key_col = FormTemplateStatus.connection.quote_column_name(:key)

    say_with_time 'Normalizing form_template_statuses keys' do
      # 1. Drop the dead intermediate step_N_approved definitions.
      #    The engine advances step_N_pending -> step_(N+1)_pending directly and
      #    never rests in step_N_approved, so these are unused.
      FormTemplateStatus.where("#{key_col} LIKE 'step_%_approved'").delete_all

      # 2. Unify the initial status: submitted/open -> in_progress (category pending).
      FormTemplateStatus.where(is_initial: true, key: %w[submitted open])
                        .update_all(key: 'in_progress', name: 'In Progress', category: 'pending')

      # 3. Every in_progress status uses category 'pending' (some forms had in_review).
      FormTemplateStatus.where(key: 'in_progress').update_all(category: 'pending')

      # 4. Remove the stray, redundant 'pending' status (carpool): not initial,
      #    not terminal, not auto-generated.
      FormTemplateStatus.where(key: 'pending', auto_generated: false, is_initial: false, is_end: false)
                        .delete_all

      # 5. Repair drifted step_N_pending categories back to in_review (e.g. WorkSchedule).
      FormTemplateStatus.where("#{key_col} LIKE 'step_%_pending'").update_all(category: 'in_review')
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Status-key consolidation cannot be reversed (original submitted/in_review values are not recoverable).'
  end
end
