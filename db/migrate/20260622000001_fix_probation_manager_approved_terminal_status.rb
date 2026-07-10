# frozen_string_literal: true

# manager_approved is the approved END STATE of a Probation Transfer Request, but
# its form_template_statuses row was configured as category "in_review" /
# is_end=false. That made approved transfers (a) linger in the inbox under the new
# terminal-status sweep and (b) display as "In Review" rather than "Approved" on
# the Submissions page. Correct the configuration. Keyed by class_name + status
# key so it applies to whichever template row exists in each environment.
class FixProbationManagerApprovedTerminalStatus < ActiveRecord::Migration[8.0]
  def up
    set_status(category: 'approved', is_end: 1)
  end

  def down
    set_status(category: 'in_review', is_end: 0)
  end

  private

  def set_status(category:, is_end:)
    execute(<<~SQL)
      UPDATE fts
      SET category = '#{category}', is_end = #{is_end}
      FROM form_template_statuses fts
      INNER JOIN form_templates ft ON ft.id = fts.form_template_id
      WHERE ft.class_name = 'ProbationTransferRequest'
        AND fts.[key] = 'manager_approved'
    SQL
  end
end
