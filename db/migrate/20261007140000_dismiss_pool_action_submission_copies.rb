# frozen_string_literal: true

# An approver who cleared a group or authorization step used to keep the form
# in their Inbox as a read-only copy. Those copies are no longer written --
# Submissions lists what someone has acted on -- so the ones still showing are
# dismissed here, as if each person had clicked Dismiss. The rows are kept.
class DismissPoolActionSubmissionCopies < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL.squish)
      UPDATE form_submission_copies
      SET dismissed_at = SYSDATETIME(), updated_at = SYSDATETIME()
      WHERE delivered_via = 'pool_action' AND dismissed_at IS NULL
    SQL
  end

  def down
    # The copies stay dismissed: nothing recorded which ones this cleared.
  end
end
