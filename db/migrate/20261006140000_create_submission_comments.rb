# frozen_string_literal: true

# One comment thread per submission, whatever the form. Polymorphic for the
# same reason record_edits and status_changes are: the inbox lists every form
# type in one table. Attachments ride on Active Storage, so there is no file
# column here.
class CreateSubmissionComments < ActiveRecord::Migration[8.1]
  def change
    create_table :submission_comments do |t|
      t.string :commentable_type, null: false
      t.bigint :commentable_id, null: false
      t.string :author_id
      t.string :author_name
      t.text :body
      t.timestamps

      t.index %i[commentable_type commentable_id created_at], name: 'index_submission_comments_on_commentable'
      t.index %i[commentable_type created_at]
    end
  end
end
