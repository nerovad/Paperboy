# frozen_string_literal: true

# A fourth thing a form subscription can follow: somebody commented on a
# submission. Off for every existing row, so nobody starts getting mail they
# did not ask for.
class AddNotifyCommentAddedToFormSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_subscriptions, :notify_comment_added, :boolean, default: false, null: false
  end
end
