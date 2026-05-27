class AddPcardStepAndDropProbationSecurity < ActiveRecord::Migration[8.0]
  # Phase 5 (central-table fixes):
  # - PcardRequestForm has a supervisor routing step but was missing its
  #   step_1_pending status, so its create action (which sets :step_1_pending)
  #   was broken. Seed the status.
  # - ProbationTransferRequest's sent_to_security status is dead (no setter, no
  #   data); remove it. Real security routing is handled via the GSA_Security
  #   group, not a per-form status.
  def up
    pcard = FormTemplate.find_by(class_name: "PcardRequestForm")
    if pcard && pcard.statuses.where(key: "step_1_pending").none?
      step = pcard.routing_steps.order(:step_number).first
      name = (step&.pending_display_name.presence) || "Sent to Supervisor"
      # Make room at position 1 by shifting the terminal statuses down.
      pcard.statuses.where(is_end: true).order(:position).each_with_index do |s, i|
        s.update_columns(position: 2 + i)
      end
      pcard.statuses.create!(
        name: name, key: "step_1_pending", category: "in_review",
        position: 1, is_initial: false, is_end: false, auto_generated: true
      )
    end

    probation = FormTemplate.find_by(class_name: "ProbationTransferRequest")
    probation&.statuses&.where(key: "sent_to_security")&.destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
