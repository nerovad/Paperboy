# frozen_string_literal: true

class CreativeJobRequest < ApplicationRecord
  # No status workflow on this form, but edits to a filed request are still
  # audited -- see AuditableEdits.
  include AuditableEdits
end
